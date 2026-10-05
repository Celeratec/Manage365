import { useCallback, useEffect, useMemo, useState } from "react";
import { useRouter } from "next/router";
import debounce from "lodash/debounce";
import { QUARANTINE_DAYS_OPTIONS } from "./quarantineConstants";

const DEFAULT_FILTER_VALUES = {
  dateFilter: "relative",
  days: QUARANTINE_DAYS_OPTIONS[1],
  startDate: null,
  endDate: null,
  sender: [],
  recipient: [],
  messageId: "",
  subject: "",
  subjectExact: "",
  senderDomain: "",
  recipientDomain: "",
  policyName: "",
  status: [],
  fromIP: "",
  toIP: "",
  quarantineType: [],
  releaseStatus: [],
  policyTypes: [],
};

const parseRouterValue = (value) => {
  if (!value) return value;
  if (Array.isArray(value)) return value[0];
  return value;
};

export const useQuarantineFilters = ({ formControl, enabled = true } = {}) => {
  const router = useRouter();
  const [debouncedSubject, setDebouncedSubject] = useState("");

  const debouncedSetSubject = useMemo(
    () =>
      debounce((value) => {
        setDebouncedSubject(value);
      }, 300),
    []
  );

  useEffect(() => () => debouncedSetSubject.cancel(), [debouncedSetSubject]);

  useEffect(() => {
    if (!enabled || !router.isReady || !formControl) return;

    const query = router.query;
    if (query.days) {
      const daysValue = parseInt(parseRouterValue(query.days), 10);
      const daysOption =
        QUARANTINE_DAYS_OPTIONS.find((option) => option.value === daysValue) ||
        QUARANTINE_DAYS_OPTIONS[1];
      formControl.setValue("dateFilter", "relative");
      formControl.setValue("days", daysOption);
    }
    if (query.sender) formControl.setValue("sender", [{ label: query.sender, value: query.sender }]);
    if (query.recipient) {
      formControl.setValue("recipient", [{ label: query.recipient, value: query.recipient }]);
    }
    if (query.subject) formControl.setValue("subject", parseRouterValue(query.subject));
    if (query.messageId) formControl.setValue("messageId", parseRouterValue(query.messageId));
  }, [enabled, formControl, router.isReady, router.query]);

  const syncFiltersToUrl = useCallback(
    (values) => {
      if (!enabled) return;
      const nextQuery = { ...router.query };
      const setOrDelete = (key, value) => {
        if (value === undefined || value === null || value === "") delete nextQuery[key];
        else nextQuery[key] = value;
      };

      if (values.messageId) {
        setOrDelete("messageId", values.messageId);
      } else {
        delete nextQuery.messageId;
        if (values.dateFilter === "relative") {
          setOrDelete("days", values.days?.value ?? values.days);
        }
        const sender = values.sender?.[0]?.value ?? values.sender?.[0];
        const recipient = values.recipient?.[0]?.value ?? values.recipient?.[0];
        setOrDelete("sender", sender);
        setOrDelete("recipient", recipient);
        setOrDelete("subject", values.subject);
      }

      router.replace({ pathname: router.pathname, query: nextQuery }, undefined, { shallow: true });
    },
    [enabled, router]
  );

  return {
    defaultFilterValues: DEFAULT_FILTER_VALUES,
    debouncedSubject,
    debouncedSetSubject,
    syncFiltersToUrl,
  };
};

export default useQuarantineFilters;
