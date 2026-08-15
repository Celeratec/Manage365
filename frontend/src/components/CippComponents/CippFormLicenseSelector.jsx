import { CippFormComponent } from "./CippFormComponent";
import { getCippLicenseTranslation } from "../../utils/get-cipp-license-translation";
import { useSettings } from "../../hooks/use-settings";

export const CippFormLicenseSelector = ({
  formControl,
  name,
  label,
  multiple = true,
  select,
  addedField,
  showRefresh = false,
  ...other
}) => {
  const userSettingsDefaults = useSettings();
  return (
    <CippFormComponent
      name={name}
      label={label}
      type="autoComplete"
      formControl={formControl}
      multiple={multiple}
      creatable={false}
      api={{
        addedField: addedField,
        tenantFilter: userSettingsDefaults.currentTenant ?? undefined,
        url: "/api/ListLicenses",
        labelField: (option) => {
          // Use License field from API response (already translated by backend)
          // Fall back to static translation if License field is missing
          const licenseName = option?.License || getCippLicenseTranslation([option])?.[0] || option?.skuPartNumber || "Unknown License";
          return `${licenseName} (${option?.availableUnits ?? 0} available)`;
        },
        valueField: "skuId",
        queryKey: `ListLicenses-${userSettingsDefaults?.currentTenant ?? undefined}`,
        data: {
          Endpoint: "subscribedSkus",
          $count: true,
          IncludeExcluded: true,
        },
        showRefresh,
      }}
    />
  );
};
