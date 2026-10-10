import {
  keepPreviousData as keepPreviousDataFn,
  useInfiniteQuery,
  useMutation,
  useQuery,
  useQueryClient,
} from "@tanstack/react-query";
import axios, { isAxiosError } from "axios";
import { useDispatch } from "react-redux";
import { showToast } from "../store/toasts";
import { getCippError } from "../utils/get-cipp-error";
import { buildVersionedHeaders } from "../utils/cippVersion";
import { impersonationCacheParams } from "../utils/impersonation";

export const STALE_TIMES = {
  FAST: 60000,
  DEFAULT: 600000,
  STABLE: 1800000,
  STATIC: 3600000,
  INFINITE: Infinity,
};

const escapeRegExp = (value) => value.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
const wildcardToRegExp = (pattern) =>
  new RegExp(`^${pattern.split("*").map(escapeRegExp).join(".*")}$`);
const matchesWildcardPattern = (queryKey, pattern) => wildcardToRegExp(pattern).test(queryKey);

const DEFAULT_GET_TIMEOUT_MS = 90000;
const AUTH_LOGIN_REDIRECT_PATH = "/.auth/login/aad";

const assertRelativeApiPath = (value) => {
  if (typeof value !== "string" || value.trim().length === 0) {
    throw new Error("Refusing empty API path");
  }
  const trimmed = value.trim();
  if (trimmed.includes("://") || trimmed.startsWith("//") || trimmed.includes("\\")) {
    throw new Error("Refusing non-relative API path");
  }
  return trimmed.startsWith("/") ? trimmed : `/${trimmed}`;
};
// 503 is omitted: Craft sheds a saturated worker with 503 and asks the client to retry.
const HTTP_STATUS_TO_NOT_RETRY = [302, 401, 403, 404, 429, 500, 502, 504];

const getRedirectLocation = (headers) => {
  if (!headers) {
    return "";
  }
  if (typeof headers.get === "function") {
    return headers.get("location") || headers.get("Location") || "";
  }
  return headers.location || headers.Location || "";
};

const isAuthRedirectError = (error) => {
  if (!isAxiosError(error) || error.response?.status !== 302) {
    return false;
  }
  return getRedirectLocation(error.response.headers).includes(AUTH_LOGIN_REDIRECT_PATH);
};

const isSessionExpiredNetworkError = (error) =>
  isAxiosError(error) &&
  !error.response &&
  error.code === "ERR_NETWORK" &&
  error.config?.url?.startsWith("/api/");

const isCancelledRequest = (error) =>
  isAxiosError(error) && (error.code === "ERR_CANCELED" || error.name === "CanceledError");

const createApiRetryFn = ({ maxRetries, queryClient, dispatch, toast, getToastTitle }) => {
  return (failureCount, error) => {
    let returnRetry = true;

    if (isCancelledRequest(error)) {
      returnRetry = false;
    } else if (failureCount >= maxRetries) {
      returnRetry = false;
    } else if (isAxiosError(error) && HTTP_STATUS_TO_NOT_RETRY.includes(error.response?.status ?? 0)) {
      if (isAuthRedirectError(error)) {
        queryClient.invalidateQueries({ queryKey: ["authmecipp"] });
      }
      returnRetry = false;
    } else if (isSessionExpiredNetworkError(error)) {
      queryClient.invalidateQueries({ queryKey: ["authmecipp"] });
      queryClient.invalidateQueries({ queryKey: ["authmeswa"] });
      returnRetry = false;
    }

    if (returnRetry === false && toast) {
      const title = getToastTitle ? getToastTitle(error) : "Error";
      dispatch(
        showToast({
          message: `${getCippError(error)}`,
          title,
          ...(title === "Error" ? { toastError: error } : {}),
        }),
      );
    }

    return returnRetry;
  };
};
// The server's Retry-After (seconds) as ms, capped so a large hint can't hang a request indefinitely.
const getRetryAfterMs = (error) => {
  if (!isAxiosError(error)) return null;
  const headers = error.response?.headers;
  const raw = headers?.get?.("retry-after") ?? headers?.["retry-after"];
  const seconds = Number(raw);
  return Number.isFinite(seconds) && seconds > 0 ? Math.min(seconds * 1000, 60000) : null;
};

// react-query's default exponential backoff, but honouring the server's Retry-After when present so a
// throttled retry lands after the limit clears instead of hammering inside the window.
const retryDelayWithRetryAfter = (failureCount, error) =>
  getRetryAfterMs(error) ?? Math.min(1000 * 2 ** failureCount, 30000);

// A request the user cancelled (navigated away / hit Cancel) aborts the axios signal and surfaces as
// a CanceledError. That is expected, not a failure: never retry it and never raise an error toast.
const isCanceledError = (error) =>
  error?.code === "ERR_CANCELED" || error?.name === "CanceledError";

export function ApiGetCall(props) {
  const {
    url,
    queryKey,
    relatedQueryKeys,
    waiting = true,
    retry = 3,
    data,
    bulkRequest = false,
    toast = false,
    onResult,
    staleTime = STALE_TIMES.DEFAULT, // Default to 10 minutes
    refetchOnWindowFocus = false,
    refetchOnMount = true,
    refetchOnReconnect = true,
    // Off by default: showing the previous query's data while a new key loads
    // can flash another tenant's rows in tenant-keyed queries. Callers that
    // want smooth transitions (e.g. the tenant selector) opt in explicitly.
    keepPreviousData = false,
    refetchInterval = false,
    responseType = "json",
    convertToDataUrl = false,
    timeout = DEFAULT_GET_TIMEOUT_MS,
  } = props;
  
  const queryClient = useQueryClient();
  const dispatch = useDispatch();
  const retryFn = createApiRetryFn({
    maxRetries: retry,
    queryClient,
    dispatch,
    toast,
    getToastTitle: (error) => {
      const tenant = error.config?.params?.tenantFilter;
      return tenant ? `${tenant} Error` : "Error";
    },
  });

  const queryInfo = useQuery({
    enabled: waiting,
    queryKey: [queryKey],
    queryFn: async ({ signal }) => {
      const safeUrl = assertRelativeApiPath(url);
      if (bulkRequest && Array.isArray(data)) {
        const results = [];
        for (let i = 0; i < data.length; i++) {
          const element = data[i];
          const response = await axios.get(safeUrl, {
            signal: signal,
            params: { ...element, ...impersonationCacheParams() },
            headers: await buildVersionedHeaders(),
            timeout,
            cippQueryKey: queryKey,
          });
          results.push(response.data);
          if (onResult) {
            onResult(response.data); // Emit each result as it arrives
          }
        }
        if (relatedQueryKeys) {
          const clearKeys = Array.isArray(relatedQueryKeys) ? relatedQueryKeys : [relatedQueryKeys];
          setTimeout(() => {
            // Separate wildcard patterns from exact keys
            const wildcardPatterns = clearKeys.filter((key) => key.includes("*"));
            const exactKeys = clearKeys.filter((key) => !key.includes("*"));

            // Use single predicate call for all wildcard patterns
            if (wildcardPatterns.length > 0) {
              queryClient.invalidateQueries({
                predicate: (query) => {
                  if (!query.queryKey || !query.queryKey[0]) return false;
                  const queryKeyStr = String(query.queryKey[0]);
                  return wildcardPatterns.some((pattern) =>
                    matchesWildcardPattern(queryKeyStr, pattern),
                  );
                },
              });
            }

            // Handle exact keys
            exactKeys.forEach((key) => {
              queryClient.invalidateQueries({ queryKey: [key] });
            });
          }, 1000);
        }
        return results;
      } else {
        const response = await axios.get(safeUrl, {
          signal: url === "/api/tenantFilter" ? null : signal,
          params: { ...data, ...impersonationCacheParams() },
          headers: await buildVersionedHeaders(),
          responseType: responseType,
          timeout,
          cippQueryKey: queryKey,
        });

        let responseData = response.data;

        // Convert blob to data URL if requested
        if (convertToDataUrl && responseType === "blob" && response.data) {
          responseData = await new Promise((resolve) => {
            const reader = new FileReader();
            reader.onloadend = () => resolve(reader.result);
            reader.readAsDataURL(response.data);
          });
        }

        if (onResult) {
          onResult(responseData); // Emit each result as it arrives
        }
        if (relatedQueryKeys) {
          const clearKeys = Array.isArray(relatedQueryKeys) ? relatedQueryKeys : [relatedQueryKeys];
          setTimeout(() => {
            // Separate wildcard patterns from exact keys
            const wildcardPatterns = clearKeys.filter((key) => key.includes("*"));
            const exactKeys = clearKeys.filter((key) => !key.includes("*"));

            // Use single predicate call for all wildcard patterns
            if (wildcardPatterns.length > 0) {
              queryClient.invalidateQueries({
                predicate: (query) => {
                  if (!query.queryKey || !query.queryKey[0]) return false;
                  const queryKeyStr = String(query.queryKey[0]);
                  return wildcardPatterns.some((pattern) =>
                    matchesWildcardPattern(queryKeyStr, pattern),
                  );
                },
              });
            }

            // Handle exact keys
            exactKeys.forEach((key) => {
              queryClient.invalidateQueries({ queryKey: [key] });
            });
          }, 1000);
        }
        return responseData;
      }
    },
    staleTime: staleTime,
    refetchOnWindowFocus: refetchOnWindowFocus,
    refetchOnMount: refetchOnMount,
    refetchOnReconnect: refetchOnReconnect,
    // TanStack Query v5 removed the `keepPreviousData` option; the equivalent
    // is passing its helper as placeholderData.
    placeholderData: keepPreviousData ? keepPreviousDataFn : undefined,
    refetchInterval: refetchInterval,
    retry: retryFn,
    retryDelay: retryDelayWithRetryAfter,
  });
  return queryInfo;
}

export function ApiPostCall({ relatedQueryKeys, onResult }) {
  const queryClient = useQueryClient();

  const mutation = useMutation({
    mutationFn: async (props) => {
      const { url, data, bulkRequest, followUps } = props;
      const safeUrl = assertRelativeApiPath(url);
      // Timeout so long-running backend calls don't hang the app (e.g. large site delete, slow APIs).
      const timeoutMs = props.timeout ?? 90000; // 90 seconds default
      const requestConfig = {
        headers: await buildVersionedHeaders(),
        timeout: timeoutMs,
      };
      if (followUps?.length) {
        // A failed primary request throws as usual and nothing else is sent. Once it has
        // succeeded, a failed follow-up is reported next to it rather than raised, so the
        // primary's results are never hidden behind a follow-up error.
        const primary = await axios.post(safeUrl, data, requestConfig);
        if (onResult) {
          onResult(primary.data);
        }
        const results = [primary.data];
        for (const followUp of followUps) {
          try {
            const response = await axios.post(assertRelativeApiPath(followUp.url), followUp.data, requestConfig);
            results.push(response.data);
          } catch (error) {
            results.push({
              Results:
                error.response?.data?.Results ?? `Failed ${followUp.url}: ${error.message}`,
            });
          }
        }
        return results;
      }
      if (bulkRequest && Array.isArray(data)) {
        const results = [];
        for (let i = 0; i < data.length; i++) {
          let element = data[i];
          const response = await axios.post(safeUrl, element, requestConfig);
          results.push(response.data);
          if (onResult) {
            onResult(response.data); // Emit each result as it arrives
          }
        }
        return results;
      } else {
        const response = await axios.post(safeUrl, data, requestConfig);
        if (onResult) {
          onResult(response.data); // Emit each result as it arrives
        }
        return response;
      }
    },
    onSuccess: () => {
      if (relatedQueryKeys) {
        const clearKeys = Array.isArray(relatedQueryKeys) ? relatedQueryKeys : [relatedQueryKeys];
        setTimeout(() => {
          if (relatedQueryKeys === "*") {
            console.log("Invalidating all queries");
            queryClient.invalidateQueries();
          } else {
            // Separate wildcard patterns from exact keys
            const wildcardPatterns = clearKeys.filter((key) => key.includes("*"));
            const exactKeys = clearKeys.filter((key) => !key.includes("*"));

            // Use single predicate call for all wildcard patterns
            if (wildcardPatterns.length > 0) {
              queryClient.invalidateQueries({
                predicate: (query) => {
                  if (!query.queryKey || !query.queryKey[0]) return false;
                  const queryKeyStr = String(query.queryKey[0]);
                  const matches = wildcardPatterns.some((pattern) =>
                    matchesWildcardPattern(queryKeyStr, pattern),
                  );

                  // Debug logging for each query check
                  if (matches) {
                    console.log("Invalidating query:", {
                      queryKey: query.queryKey,
                      queryKeyStr,
                      matchedPattern: wildcardPatterns.find((pattern) =>
                        matchesWildcardPattern(queryKeyStr, pattern),
                      ),
                    });
                  }

                  return matches;
                },
              });
            }

            // Handle exact keys
            exactKeys.forEach((key) => {
              queryClient.invalidateQueries({ queryKey: [key] });
            });
          }
        }, 1000);
      }
    },
  });

  return mutation;
}

export function ApiGetCallWithPagination({
  url,
  queryKey,
  retry = 3,
  data,
  toast = false,
  waiting = true,
  refetchOnMount = false,
  timeout = DEFAULT_GET_TIMEOUT_MS,
}) {
  const dispatch = useDispatch();
  const queryClient = useQueryClient();
  const retryFn = createApiRetryFn({
    maxRetries: retry,
    queryClient,
    dispatch,
    toast,
  });

  const queryInfo = useInfiniteQuery({
    queryKey: [queryKey],
    enabled: waiting,
    queryFn: async ({ pageParam = null, signal }) => {
      const safeUrl = assertRelativeApiPath(url);
      const response = await axios.get(safeUrl, {
        signal: signal,
        params: { ...data, ...pageParam, ...impersonationCacheParams() },
        headers: await buildVersionedHeaders(),
        timeout,
        cippQueryKey: queryKey,
      });
      return response.data;
    },
    getNextPageParam: (lastPage) => {
      // AllTenants pages only when the page opted into manualPagination.
      if (
        data?.noPagination ||
        data?.manualPagination === false ||
        (data?.tenantFilter === "AllTenants" && data?.manualPagination !== true)
      ) {
        return undefined;
      }
      return lastPage?.Metadata?.nextLink ? { nextLink: lastPage.Metadata.nextLink } : undefined;
    },
    staleTime: STALE_TIMES.DEFAULT,
    refetchOnWindowFocus: false,
    refetchOnMount: refetchOnMount,
    retry: retryFn,
    retryDelay: retryDelayWithRetryAfter,
  });

  return queryInfo;
}
