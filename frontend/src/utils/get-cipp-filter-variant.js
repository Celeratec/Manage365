import { getCippUniqueLicenses } from "./get-cipp-unique-licenses";

// Named (not inline) so it can be registered under a string key in CippDataTable's
// filterFns — an inline function here leaves MRT unable to resolve a "Filter Mode" label.
export const licenseIncludesFilterFn = (row, columnId, filterValue) => {
  const userLicenses = row.original.assignedLicenses;
  const hasLicenses = Array.isArray(userLicenses) && userLicenses.length > 0;
  if (filterValue === "licensed") return hasLicenses;
  if (filterValue === "unlicensed") return !hasLicenses;
  if (Array.isArray(filterValue)) {
    if (filterValue.includes("licensed")) return hasLicenses;
    if (filterValue.includes("unlicensed")) return !hasLicenses;
  }
  if (!filterValue || !Array.isArray(filterValue) || filterValue.length === 0) {
    return true;
  }

  const hasNoLicenseFilter = filterValue.includes("__no_license__");
  const otherFilters = filterValue.filter((v) => v !== "__no_license__");
  const isUnlicensed = !userLicenses || !Array.isArray(userLicenses) || userLicenses.length === 0;

  // If user selected "No Licenses Assigned" and this user is unlicensed → match
  if (hasNoLicenseFilter && isUnlicensed) {
    return true;
  }

  // If only "No Licenses Assigned" is selected and user has licenses → no match
  if (hasNoLicenseFilter && otherFilters.length === 0 && !isUnlicensed) {
    return false;
  }

  // Check other license filters
  if (isUnlicensed) {
    return false;
  }

  const userSkuIds = userLicenses.map((license) => license.skuId).filter(Boolean);
  return otherFilters.some((selectedSkuId) => userSkuIds.includes(selectedSkuId));
};

export const getCippFilterVariant = (providedColumnKeys, arg) => {
  // Back-compat + new options mode
  const isOptions =
    arg &&
    typeof arg === "object" &&
    (Object.prototype.hasOwnProperty.call(arg, "sampleValue") ||
      Array.isArray(arg?.values) ||
      typeof arg?.getValue === "function");

  const sampleValue = isOptions ? arg.sampleValue : arg;
  const values = isOptions && Array.isArray(arg.values) ? arg.values : undefined;
  const tailKey = providedColumnKeys?.split(".").pop() ?? providedColumnKeys;

  const timeAgoArray = [
    "ExecutedTime",
    "ScheduledTime",
    "Timestamp",
    "DateTime",
    "LastRun",
    "LastRefresh",
    "createdDateTime",
    "activatedDateTime",
    "lastModifiedDateTime",
    "endDateTime",
    "ReceivedTime",
    "Expires",
    "updatedAt",
    "createdAt",
    "Received",
    "Date",
    "WhenCreated",
    "WhenChanged",
  ];
  const matchDateTime =
    /[dD]ate(?:[tT]ime)?|(?:^|\.)(?:updatedAt|createdAt|LastRun|LastRefresh|Expires)$/;

  const typeOf = typeof sampleValue;
  //First key based filters
  switch (tailKey) {
    case "assignedLicenses":
      // Extract unique licenses from the data if available
      let filterSelectOptions = [];
      if (isOptions && arg.dataArray && Array.isArray(arg.dataArray)) {
        const uniqueLicenses = getCippUniqueLicenses(arg.dataArray);
        filterSelectOptions = uniqueLicenses.map((license) => ({
          label: license.displayName,
          value: license.skuId,
        }));
      }

      // Add "No Licenses Assigned" option at beginning
      filterSelectOptions.unshift({
        label: "No Licenses Assigned",
        value: "__no_license__",
      });

      return {
        filterVariant: "multi-select",
        sortingFn: "alphanumeric",
        // string name (registered in CippDataTable's FILTER_FNS) so MRT can resolve a
        // "Filter Mode" label — an inline function here can't be looked up by name.
        filterFn: "licenseIncludes",
        filterSelectOptions: filterSelectOptions,
      };
    case "accountEnabled":
      return {
        filterVariant: "select",
        sortingFn: "alphanumeric",
        filterFn: (row, columnId, filterValue) => {
          const rawValue = row.original.accountEnabled;
          const isEnabled = rawValue === true || rawValue === "true" || rawValue === "Yes";
          
          // Handle "Yes"/"No" filter values (from preset filters or column filter dropdown)
          if (filterValue === "Yes" || filterValue === true) {
            return isEnabled;
          }
          if (filterValue === "No" || filterValue === false) {
            return !isEnabled;
          }
          
          // Handle array of filter values
          if (Array.isArray(filterValue)) {
            if (filterValue.length === 0) {
              return true;
            }
            if (filterValue.includes("Yes") || filterValue.includes(true)) {
              return isEnabled;
            }
            if (filterValue.includes("No") || filterValue.includes(false)) {
              return !isEnabled;
            }
          }
          
          // No filter or empty - show all
          return true;
        },
      };
    case "primDomain":
      return {
        filterVariant: "select",
        sortingFn: "alphanumeric",
        filterFn: "includes",
      };
    case "number":
      return {
        filterVariant: "range",
        sortingFn: "number",
        filterFn: "betweenInclusive",
      };
    case "id":
      return {
        filterVariant: "text",
        sortingFn: "alphanumeric",
        filterFn: "includes",
      };
  }
  //Type based filters
  if (typeOf === "boolean") {
    return {
      filterVariant: "select",
      sortingFn: "boolean",
      filterFn: "equals",
      filterSelectOptions: ["Yes", "No"],
    };
  }

  if (typeOf === "number") {
    return {
      filterVariant: "range",
      sortingFn: "number",
      filterFn: "betweenInclusive",
    };
  }

  if (timeAgoArray.includes(tailKey) || matchDateTime.test(providedColumnKeys)) {
    return {
      filterVariant: "datetime-range",
      sortingFn: "dateTimeNullsLast",
      filterFn: "betweenInclusive",
    };
  }
};
