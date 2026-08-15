import { getCachedLicense } from "./cipp-license-cache";
import licenseBackfillManager from "./cipp-license-backfill-manager";

// Lazy-load the ~2.1MB M365 license JSON files only when needed
let _m365LicensesCache = null;
const getM365Licenses = async () => {
  if (_m365LicensesCache) return _m365LicensesCache;
  const [defaultMod, additionalMod] = await Promise.all([
    import("../data/M365Licenses.json"),
    import("../data/M365Licenses-additional.json"),
  ]);
  _m365LicensesCache = [...defaultMod.default, ...additionalMod.default];
  return _m365LicensesCache;
};

// Synchronous cache accessor for when data is already loaded
const getM365LicensesSync = () => _m365LicensesCache || [];

// Helper function to clean up technical license names (skuPartNumber)
// Converts names like "DEFENDER_ENDPOINT_P2_XPLAT" to "Defender Endpoint P2"
const formatSkuPartNumber = (skuPartNumber) => {
  if (!skuPartNumber) return null;
  
  // List of technical suffixes to remove
  const suffixesToRemove = [
    "_XPLAT",        // Cross-platform
    "_GOV",          // Government
    "_USGOV",        // US Government  
    "_DOD",          // Department of Defense
    "_GCC",          // Government Community Cloud
    "_GCCHIGH",      // GCC High
    "_EDU",          // Education (sometimes appended)
    "_FACULTY",      // Faculty
    "_STUDENT",      // Student
    "_NONPROFIT",    // Nonprofit
  ];
  
  let cleaned = skuPartNumber;
  
  // Remove technical suffixes (case-insensitive)
  suffixesToRemove.forEach((suffix) => {
    const regex = new RegExp(suffix + "$", "i");
    cleaned = cleaned.replace(regex, "");
  });
  
  // Replace underscores with spaces
  cleaned = cleaned.replace(/_/g, " ");
  
  // Title case each word (but preserve common acronyms)
  const acronyms = ["ATP", "EMS", "AAD", "O365", "M365", "SPE", "SPB", "P1", "P2", "E1", "E3", "E5", "F1", "F3", "G1", "G3", "G5", "A1", "A3", "A5", "K1"];
  cleaned = cleaned
    .split(" ")
    .map((word) => {
      const upper = word.toUpperCase();
      if (acronyms.includes(upper)) {
        return upper;
      }
      // Title case: first letter uppercase, rest lowercase
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .join(" ");
  
  // Clean up common technical terms to friendly names
  const replacements = {
    "Atp Enterprise": "Microsoft Defender for Office 365 P1",
    "Atp Enterprise Premium": "Microsoft Defender for Office 365 P2",
    "Defender Endpoint": "Microsoft Defender for Endpoint",
    "Defender Endpoint P1": "Microsoft Defender for Endpoint P1",
    "Defender Endpoint P2": "Microsoft Defender for Endpoint P2",
    "Enterprisepack": "Office 365 E3",
    "Enterprisepremium": "Office 365 E5",
    "Spe E3": "Microsoft 365 E3",
    "Spe E5": "Microsoft 365 E5",
    "Spb": "Microsoft 365 Business Premium",
    "Desklesspack": "Office 365 F3",
    "Standardpack": "Office 365 E1",
    "Flow Free": "Power Automate Free",
    "Powerapps Viral": "Power Apps Trial",
    "Teams Exploratory": "Microsoft Teams Exploratory",
    "Power Bi Free": "Power BI Free",
    "Power Bi Standard": "Power BI Pro",
    "Power Bi Pro": "Power BI Pro",
    "Visioclient": "Visio Plan 2",
    "Projectprofessional": "Project Plan 3",
    "Projectpremium": "Project Plan 5",
    "Rightsmanagement Adhoc": "Azure Information Protection",
    "Emspremium": "Enterprise Mobility + Security E5",
    "Ems": "Enterprise Mobility + Security E3",
    "Aadp1": "Microsoft Entra ID P1",
    "Aadp2": "Microsoft Entra ID P2",
    "Aad Premium": "Microsoft Entra ID P1",
    "Aad Premium P2": "Microsoft Entra ID P2",
    "Intune A Direct": "Microsoft Intune",
    "Win Def Atp": "Microsoft Defender for Endpoint",
  };
  
  // Check for replacements (case-insensitive)
  const cleanedLower = cleaned.toLowerCase();
  for (const [key, value] of Object.entries(replacements)) {
    if (cleanedLower === key.toLowerCase()) {
      return value;
    }
  }
  
  return cleaned;
};

// Pre-warm the cache on module load (non-blocking)
getM365Licenses();

export const getCippLicenseTranslation = (licenseArray) => {
  const M365Licenses = getM365LicensesSync();
  let licenses = [];
  let missingSkuIds = [];

  if (Array.isArray(licenseArray) && typeof licenseArray[0] === "string") {
    return licenseArray;
  }

  if (!Array.isArray(licenseArray) && typeof licenseArray === "object") {
    licenseArray = [licenseArray];
  }

  if (!licenseArray || licenseArray.length === 0) {
    return ["No Licenses Assigned"];
  }

  licenseArray?.forEach((licenseAssignment) => {
    if (!licenseAssignment) {
      return;
    }
    
    let found = false;

    // 1. Check static JSON files
    for (let x = 0; x < M365Licenses.length; x++) {
      if (licenseAssignment.skuId === M365Licenses[x].GUID) {
        const displayName = M365Licenses[x].Product_Display_Name;
        if (displayName) {
          licenses.push(displayName);
        } else {
          const formatted = formatSkuPartNumber(licenseAssignment.skuPartNumber);
          licenses.push(formatted || `License (${licenseAssignment.skuId?.substring(0, 8) || "Unknown"})`);
        }
        found = true;
        break;
      }
    }

    if (!found && licenseAssignment.skuId) {
      // 2. Check dynamic cache (populated by backfill API)
      const cachedName = getCachedLicense(licenseAssignment.skuId);
      if (cachedName) {
        licenses.push(cachedName);
        found = true;
      }
    }

    if (!found) {
      // 3. Use formatted skuPartNumber as immediate fallback
      const formatted = formatSkuPartNumber(licenseAssignment.skuPartNumber);
      if (formatted) {
        licenses.push(formatted);
      } else if (licenseAssignment.skuId) {
        licenses.push(`License (${licenseAssignment.skuId.substring(0, 8)}...)`);
      }

      // 4. Queue for API backfill so the display auto-refreshes with accurate names
      if (licenseAssignment.skuId) {
        missingSkuIds.push(licenseAssignment.skuId);
      }
    }
  });

  if (missingSkuIds.length > 0) {
    licenseBackfillManager.addMissingSkuIds(missingSkuIds);
  }

  if (!licenses || licenses.length === 0) {
    return ["No Licenses Assigned"];
  }
  return licenses;
};
