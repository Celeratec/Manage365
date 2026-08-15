/**
 * Phone number formatting utilities for international phone numbers
 * Handles parsing, validation, and formatting of phone numbers
 */

// Common country codes and their expected formats
const COUNTRY_PHONE_CONFIG = {
  US: { code: '+1', minLength: 10, maxLength: 10 },
  CA: { code: '+1', minLength: 10, maxLength: 10 },
  GB: { code: '+44', minLength: 10, maxLength: 10 },
  AU: { code: '+61', minLength: 9, maxLength: 9 },
  DE: { code: '+49', minLength: 10, maxLength: 11 },
  FR: { code: '+33', minLength: 9, maxLength: 9 },
  NL: { code: '+31', minLength: 9, maxLength: 9 },
  BE: { code: '+32', minLength: 8, maxLength: 9 },
  ES: { code: '+34', minLength: 9, maxLength: 9 },
  IT: { code: '+39', minLength: 9, maxLength: 10 },
  CH: { code: '+41', minLength: 9, maxLength: 9 },
  AT: { code: '+43', minLength: 10, maxLength: 13 },
  NZ: { code: '+64', minLength: 8, maxLength: 10 },
  IE: { code: '+353', minLength: 9, maxLength: 9 },
  MX: { code: '+52', minLength: 10, maxLength: 10 },
  BR: { code: '+55', minLength: 10, maxLength: 11 },
  IN: { code: '+91', minLength: 10, maxLength: 10 },
  JP: { code: '+81', minLength: 10, maxLength: 10 },
  CN: { code: '+86', minLength: 11, maxLength: 11 },
  KR: { code: '+82', minLength: 9, maxLength: 10 },
  SG: { code: '+65', minLength: 8, maxLength: 8 },
  HK: { code: '+852', minLength: 8, maxLength: 8 },
  ZA: { code: '+27', minLength: 9, maxLength: 9 },
  AE: { code: '+971', minLength: 9, maxLength: 9 },
  IL: { code: '+972', minLength: 9, maxLength: 9 },
  SE: { code: '+46', minLength: 9, maxLength: 9 },
  NO: { code: '+47', minLength: 8, maxLength: 8 },
  DK: { code: '+45', minLength: 8, maxLength: 8 },
  FI: { code: '+358', minLength: 9, maxLength: 10 },
  PL: { code: '+48', minLength: 9, maxLength: 9 },
  PT: { code: '+351', minLength: 9, maxLength: 9 },
};

/**
 * Remove all non-digit characters except leading +
 * @param {string} phone - The phone number to clean
 * @returns {string} - Cleaned phone number
 */
export const cleanPhoneNumber = (phone) => {
  if (!phone || typeof phone !== 'string') return '';
  
  // Preserve the leading + if present
  const hasPlus = phone.trim().startsWith('+');
  
  // Remove all non-digit characters
  const digits = phone.replace(/\D/g, '');
  
  return hasPlus ? `+${digits}` : digits;
};

/**
 * Detect if a phone number already has a country code
 * @param {string} phone - The cleaned phone number
 * @returns {object|null} - Country info if detected, null otherwise
 */
const detectCountryCode = (phone) => {
  if (!phone.startsWith('+')) return null;
  
  const digits = phone.substring(1);
  
  // Check for common country codes (sorted by length to match longest first)
  const sortedConfigs = Object.entries(COUNTRY_PHONE_CONFIG)
    .sort((a, b) => b[1].code.length - a[1].code.length);
  
  for (const [country, config] of sortedConfigs) {
    const codeDigits = config.code.substring(1); // Remove the +
    if (digits.startsWith(codeDigits)) {
      return { country, ...config };
    }
  }
  
  // If starts with + but not recognized, assume it's a valid international number
  return { country: 'UNKNOWN', code: '', minLength: 7, maxLength: 15 };
};

/**
 * Format a phone number to E.164 format (+1234567890)
 * @param {string} phone - The input phone number
 * @param {string} defaultCountry - Default country code (e.g., 'US', 'GB')
 * @returns {string} - E.164 formatted phone number or original if cannot parse
 */
export const formatPhoneE164 = (phone, defaultCountry = 'US') => {
  if (!phone || typeof phone !== 'string') return '';
  
  const cleaned = cleanPhoneNumber(phone);
  if (!cleaned) return '';
  
  // If already has a country code
  if (cleaned.startsWith('+')) {
    return cleaned;
  }
  
  // Get default country config
  const countryConfig = COUNTRY_PHONE_CONFIG[defaultCountry] || COUNTRY_PHONE_CONFIG.US;
  
  // Handle numbers that start with country code without +
  // e.g., "1234567890" for US numbers or "44123456789" for UK
  const defaultCodeDigits = countryConfig.code.substring(1);
  
  if (cleaned.startsWith(defaultCodeDigits) && cleaned.length > countryConfig.maxLength) {
    // Number includes country code, add +
    return `+${cleaned}`;
  }
  
  // For US/Canada, handle numbers starting with 1
  if ((defaultCountry === 'US' || defaultCountry === 'CA') && cleaned.startsWith('1') && cleaned.length === 11) {
    return `+${cleaned}`;
  }
  
  // Add default country code
  return `${countryConfig.code}${cleaned}`;
};

/**
 * Format a phone number for display (human-readable)
 * @param {string} phone - The input phone number (preferably E.164)
 * @param {string} defaultCountry - Default country code for formatting
 * @returns {string} - Formatted display string
 */
export const formatPhoneDisplay = (phone, defaultCountry = 'US') => {
  if (!phone || typeof phone !== 'string') return '';
  
  // First normalize to E.164
  const e164 = formatPhoneE164(phone, defaultCountry);
  if (!e164) return phone;
  
  const detected = detectCountryCode(e164);
  if (!detected) return e164;
  
  const codeDigits = detected.code.substring(1);
  const nationalNumber = e164.substring(1 + codeDigits.length);
  
  // Format based on country
  switch (detected.country) {
    case 'US':
    case 'CA':
      // Format: +1 (xxx) xxx-xxxx
      if (nationalNumber.length === 10) {
        return `${detected.code} (${nationalNumber.substring(0, 3)}) ${nationalNumber.substring(3, 6)}-${nationalNumber.substring(6)}`;
      }
      break;
    
    case 'GB':
      // Format: +44 xxxx xxxxxx or +44 xxxxx xxxxx
      if (nationalNumber.length >= 10) {
        return `${detected.code} ${nationalNumber.substring(0, 4)} ${nationalNumber.substring(4)}`;
      }
      break;
    
    case 'AU':
      // Format: +61 x xxxx xxxx
      if (nationalNumber.length >= 9) {
        return `${detected.code} ${nationalNumber.substring(0, 1)} ${nationalNumber.substring(1, 5)} ${nationalNumber.substring(5)}`;
      }
      break;
    
    case 'DE':
      // Format: +49 xxx xxxxxxx
      if (nationalNumber.length >= 10) {
        return `${detected.code} ${nationalNumber.substring(0, 3)} ${nationalNumber.substring(3)}`;
      }
      break;
    
    case 'FR':
      // Format: +33 x xx xx xx xx
      if (nationalNumber.length === 9) {
        return `${detected.code} ${nationalNumber.substring(0, 1)} ${nationalNumber.substring(1, 3)} ${nationalNumber.substring(3, 5)} ${nationalNumber.substring(5, 7)} ${nationalNumber.substring(7)}`;
      }
      break;
    
    default:
      // Generic international format: +xx xxx xxx xxxx
      if (nationalNumber.length >= 7) {
        // Split into groups of 3-3-4 or similar
        const groups = [];
        let remaining = nationalNumber;
        while (remaining.length > 0) {
          if (remaining.length <= 4) {
            groups.push(remaining);
            break;
          }
          groups.push(remaining.substring(0, 3));
          remaining = remaining.substring(3);
        }
        return `${detected.code} ${groups.join(' ')}`;
      }
  }
  
  // Fallback: return E.164 with spaces
  return e164;
};

/**
 * Validate a phone number
 * @param {string} phone - The phone number to validate
 * @param {string} defaultCountry - Default country code
 * @returns {object} - { valid: boolean, message?: string, formatted?: string }
 */
export const validatePhoneNumber = (phone, defaultCountry = 'US') => {
  if (!phone || typeof phone !== 'string') {
    return { valid: true }; // Empty is valid (not required)
  }
  
  const cleaned = cleanPhoneNumber(phone);
  if (!cleaned) {
    return { valid: true }; // Empty after cleaning is valid
  }
  
  // Normalize to E.164
  const e164 = formatPhoneE164(cleaned, defaultCountry);
  const detected = detectCountryCode(e164);
  
  if (!detected) {
    return { 
      valid: false, 
      message: 'Invalid phone number format' 
    };
  }
  
  // Get the national number (without country code)
  const codeDigits = detected.code ? detected.code.substring(1) : '';
  const nationalNumber = e164.startsWith('+') 
    ? e164.substring(1 + codeDigits.length) 
    : e164;
  
  // Check length
  if (nationalNumber.length < detected.minLength) {
    return { 
      valid: false, 
      message: `Phone number is too short (minimum ${detected.minLength} digits)` 
    };
  }
  
  if (nationalNumber.length > detected.maxLength + 2) { // Allow some flexibility
    return { 
      valid: false, 
      message: `Phone number is too long` 
    };
  }
  
  return { 
    valid: true, 
    formatted: e164,
    display: formatPhoneDisplay(e164, defaultCountry)
  };
};

/**
 * React Hook form compatible validator
 * @param {string} defaultCountry - Default country code
 * @returns {function} - Validator function
 */
export const phoneValidator = (defaultCountry = 'US') => (value) => {
  if (!value) return true; // Empty is valid (use required validator if needed)
  
  const result = validatePhoneNumber(value, defaultCountry);
  return result.valid || result.message;
};

/**
 * Format phone on blur handler for form inputs
 * @param {string} value - Current input value
 * @param {function} onChange - Form onChange handler
 * @param {string} defaultCountry - Default country code
 */
export const handlePhoneBlur = (value, onChange, defaultCountry = 'US') => {
  if (!value) return;
  
  const result = validatePhoneNumber(value, defaultCountry);
  if (result.valid && result.formatted) {
    onChange(result.formatted);
  }
};

export default {
  cleanPhoneNumber,
  formatPhoneE164,
  formatPhoneDisplay,
  validatePhoneNumber,
  phoneValidator,
  handlePhoneBlur,
};
