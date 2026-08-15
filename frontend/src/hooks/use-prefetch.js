import { useQueryClient } from "@tanstack/react-query";
import { useCallback, useEffect } from "react";
import axios from "axios";
import { buildVersionedHeaders } from "../utils/cippVersion";
import { STALE_TIMES } from "../api/ApiCall";

/**
 * Hook to prefetch data for likely navigation destinations
 * Call this on pages where users frequently navigate to predictable next pages
 */
export const usePrefetch = () => {
  const queryClient = useQueryClient();

  const prefetchQuery = useCallback(
    async (url, queryKey, data = {}, staleTime = STALE_TIMES.DEFAULT) => {
      // Only prefetch if not already cached
      const existingData = queryClient.getQueryData([queryKey]);
      if (existingData) return;

      try {
        await queryClient.prefetchQuery({
          queryKey: [queryKey],
          queryFn: async () => {
            const response = await axios.get(url, {
              params: data,
              headers: await buildVersionedHeaders(),
            });
            return response.data;
          },
          staleTime: staleTime,
        });
      } catch (error) {
        // Silently fail - prefetch is opportunistic
        console.debug(`Prefetch failed for ${queryKey}:`, error.message);
      }
    },
    [queryClient]
  );

  return { prefetchQuery };
};

/**
 * Hook to prefetch common data when dashboard loads
 * This preloads data for frequently accessed pages
 */
export const useDashboardPrefetch = (currentTenant) => {
  const { prefetchQuery } = usePrefetch();

  useEffect(() => {
    if (!currentTenant || currentTenant === "AllTenants") return;

    // Delay prefetching to not compete with dashboard's own data loading
    const timeoutId = setTimeout(() => {
      // Prefetch users list (very commonly accessed from dashboard)
      prefetchQuery(
        "/api/ListGraphRequest",
        `${currentTenant}-users-prefetch`,
        {
          Endpoint: "users",
          tenantFilter: currentTenant,
          $select: "id,displayName,userPrincipalName,mail,accountEnabled,jobTitle,department",
          $top: 100,
          $orderby: "displayName",
        },
        STALE_TIMES.DEFAULT
      );

      // Prefetch groups list
      prefetchQuery(
        "/api/ListGroups",
        `${currentTenant}-groups-prefetch`,
        { tenantFilter: currentTenant },
        STALE_TIMES.DEFAULT
      );

      // Prefetch devices list (if Intune is commonly used)
      prefetchQuery(
        "/api/ListGraphRequest",
        `${currentTenant}-devices-prefetch`,
        {
          Endpoint: "deviceManagement/managedDevices",
          tenantFilter: currentTenant,
          $top: 50,
        },
        STALE_TIMES.DEFAULT
      );
    }, 2000); // Wait 2 seconds after dashboard loads

    return () => clearTimeout(timeoutId);
  }, [currentTenant, prefetchQuery]);
};

/**
 * Hook to prefetch on hover - for menus and navigation
 * Usage: onMouseEnter={() => prefetchOnHover('/api/ListUsers', 'users')}
 */
export const usePrefetchOnHover = () => {
  const { prefetchQuery } = usePrefetch();

  const prefetchOnHover = useCallback(
    (url, queryKey, data = {}) => {
      // Debounce by checking if already prefetching
      prefetchQuery(url, queryKey, data);
    },
    [prefetchQuery]
  );

  return { prefetchOnHover };
};

export default usePrefetch;
