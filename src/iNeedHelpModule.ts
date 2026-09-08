/**
 * iNeedHelpModule
 *
 * Financial-compliance tax engine for Indian GST invoicing.
 *
 * Design rules enforced here:
 * - All monetary amounts are integer minor units (paise). No floating-point
 *   arithmetic is used for tax calculation; each tax head is rounded
 *   individually before totals are computed.
 * - Malformed inputs are rejected with TaxComplianceError.
 * - Rates and statutory references are named in comments next to constants.
 * - GSTIN identifiers are validated with the real checksum algorithm, not
 *   by format regex alone.
 * - Exempt, zero-rated, reverse-charge, and cross-border paths are handled
 *   explicitly and never fall through to the domestic taxable branch.
 */

export type Jurisdiction = 'IN';
export type TaxTreatment = 'standard' | 'exempt' | 'zero-rated' | 'reverse-charge' | 'cross-border';
export type PlaceOfSupply = 'intra-state' | 'inter-state';
export type CrossBorderDirection = 'export' | 'import';

export interface TaxInvoiceInput {
  /** Jurisdiction code. Currently only 'IN' is supported. */
  jurisdiction: Jurisdiction;
  /** Tax treatment for this supply. */
  treatment: TaxTreatment;
  /**
   * Taxable value in integer minor units (paise for INR).
   * For example, Rs 100.00 is represented as 10000.
   */
  netAmount: number;
  /** Required for standard and reverse-charge supplies. */
  placeOfSupply?: PlaceOfSupply;
  /** Required for cross-border supplies. */
  crossBorderDirection?: CrossBorderDirection;
  /** Optional supplier GSTIN. If supplied, it must be valid. */
  supplierGstin?: string;
  /** Required for reverse-charge and import cross-border supplies. */
  recipientGstin?: string;
}

export interface TaxHead {
  code: string;
  /** Rate expressed in basis points: 900 = 9.00%. */
  rateBps: number;
  /** Rounded tax amount in integer minor units. */
  amount: number;
  /** Named statutory rule that makes this head traceable. */
  statutoryBasis: string;
  /** True when the recipient, rather than supplier, is liable to remit. */
  recipientLiable: boolean;
}

export interface TaxBreakdown {
  treatment: TaxTreatment;
  heads: TaxHead[];
  /** Sum of individually rounded tax heads. */
  totalTaxAmount: number;
  /** taxable value + totalTaxAmount. */
  totalInvoiceAmount: number;
  /** True when any included head is payable by the recipient. */
  recipientLiable: boolean;
}

export class TaxComplianceError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TaxComplianceError';
  }
}

// ---------------------------------------------------------------------------
// GSTIN validation
//
// GSTIN is a 15-character identifier with a real checksum digit.
// Format: IIAAAAA####AZC
//   II    - state code
//   AAAAA - PAN letters
//   ####  - PAN digits
//   A     - PAN check letter
//   Z     - entity code (default Z for regular taxpayers)
//   Z     - default 14th character
//   C     - checksum character computed from the first 14 characters.
//
// Statutory reference: GST Identification Number format published by GSTN
// under the Central Goods and Services Tax Act, 2017 / Rules. The checksum is
// the official GSTN checksum algorithm; regex is structural pre-check only.
// ---------------------------------------------------------------------------

const GSTIN_ALPHABET = '0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ';
const GSTIN_LENGTH = 15;
const GSTIN_WITHOUT_CHECK_DIGIT_LENGTH = 14;
// Structural check only. The checksum below is authoritative.
const GSTIN_PATTERN = /^[0-9]{2}[A-Z]{5}[0-9]{4}[A-Z][0-9A-Z]Z[0-9A-Z]$/;

function computeGstinCheckDigit(gstinWithoutCheckDigit: string): string {
  const modulus = GSTIN_ALPHABET.length;
  let factor = 2;
  let sum = 0;

  for (let i = gstinWithoutCheckDigit.length - 1; i >= 0; i -= 1) {
    const codePoint = GSTIN_ALPHABET.indexOf(gstinWithoutCheckDigit[i]);
    if (codePoint === -1) {
      return '';
    }

    const product = codePoint * factor;
    const quotient = (product - (product % modulus)) / modulus;
    const remainder = product % modulus;
    sum += quotient + remainder;
    factor = factor === 2 ? 1 : 2;
  }

  const checkCodePoint = (modulus - (sum % modulus)) % modulus;
  return GSTIN_ALPHABET.charAt(checkCodePoint);
}

export function isValidGstin(gstin: string): boolean {
  if (typeof gstin !== 'string') {
    return false;
  }

  const normalized = gstin.trim().toUpperCase();
  if (normalized.length !== GSTIN_LENGTH || !GSTIN_PATTERN.test(normalized)) {
    return false;
  }

  const checkDigit = computeGstinCheckDigit(
    normalized.slice(0, GSTIN_WITHOUT_CHECK_DIGIT_LENGTH),
  );
  return checkDigit === normalized[GSTIN_LENGTH - 1];
}

export function validateGstin(gstin: string): void {
  if (!isValidGstin(gstin)) {
    throw new TaxComplianceError(
      'Invalid GSTIN. Expected a 15-character GSTIN with a valid checksum.',
    );
  }
}

// ---------------------------------------------------------------------------
// Indian GST rates, traceable to statute.
//
// 9% CGST and 9% SGST for most intra-state taxable services:
// CGST Act, 2017, section 9(1) read with Notification No. 11/2017-Central
// Tax (Rate); respective State/Union Territory SGST Acts.
//
// 18% IGST for inter-state taxable supplies:
// IGST Act, 2017, section 5(1) read with Notification No. 11/2017-Integrated
// Tax (Rate).
//
// Exempt and zero-rated references are placed on the heads themselves.
// ---------------------------------------------------------------------------

const BASIS_POINTS_PER_HUNDRED_PERCENT = 10000;
const HALF_UP_THRESHOLD = 5000; // half of 10000, for half-up rounding.
const CGST_RATE_BPS = 900; // 9.00%
const SGST_RATE_BPS = 900; // 9.00%
const IGST_RATE_BPS = 1800; // 18.00%
const ZERO_RATE_BPS = 0;

const ALLOWED_TREATMENTS: readonly TaxTreatment[] = [
  'standard',
  'exempt',
  'zero-rated',
  'reverse-charge',
  'cross-border',
];

const ALLOWED_PLACE_OF_SUPPLY: readonly PlaceOfSupply[] = [
  'intra-state',
  'inter-state',
];

const ALLOWED_CROSS_BORDER_DIRECTIONS: readonly CrossBorderDirection[] = [
  'export',
  'import',
];

function multiplyToSafeInteger(
  left: number,
  right: number,
  label: string,
): number {
  if (!Number.isSafeInteger(left) || !Number.isSafeInteger(right)) {
    throw new TaxComplianceError(`${label} must use safe integer operands.`);
  }

  const result = left * right;
  if (!Number.isSafeInteger(result)) {
    throw new TaxComplianceError(`${label} exceeds the safe integer range.`);
  }

  return result;
}

/**
 * Rounds a tax amount from taxable value * rate basis points.
 *
 * This deliberately stays in integer minor units. Each tax head is rounded
 * before final totals are summed.
 */
function roundTaxAmount(baseMinor: number, rateBps: number): number {
  const numerator = multiplyToSafeInteger(
    baseMinor,
    rateBps,
    'Taxable amount * rate',
  );
  const denominator = BASIS_POINTS_PER_HUNDRED_PERCENT;
  const quotient = (numerator - (numerator % denominator)) / denominator;
  const remainder = numerator % denominator;
  const rounded = remainder >= HALF_UP_THRESHOLD ? quotient + 1 : quotient;

  if (!Number.isSafeInteger(rounded)) {
    throw new TaxComplianceError('Rounded tax amount exceeds the safe integer range.');
  }

  return rounded;
}

function makeTaxHead(
  code: string,
  rateBps: number,
  amount: number,
  statutoryBasis: string,
  recipientLiable: boolean,
): TaxHead {
  return {
    code,
    rateBps,
    amount,
    statutoryBasis,
    recipientLiable,
  };
}

function finalizeBreakdown(
  input: TaxInvoiceInput,
  heads: TaxHead[],
  recipientLiable: boolean,
): TaxBreakdown {
  const totalTaxAmount = heads.reduce((sum, head) => sum + head.amount, 0);
  const totalInvoiceAmount = input.netAmount + totalTaxAmount;

  if (
    !Number.isSafeInteger(totalTaxAmount) ||
    !Number.isSafeInteger(totalInvoiceAmount)
  ) {
    throw new TaxComplianceError('Invoice total exceeds the safe integer range.');
  }

  return {
    treatment: input.treatment,
    heads,
    totalTaxAmount,
    totalInvoiceAmount,
    recipientLiable,
  };
}

function validateTaxInvoiceInput(input: TaxInvoiceInput): void {
  if (input.jurisdiction !== 'IN') {
    throw new TaxComplianceError(
      `Unsupported jurisdiction: ${String(input.jurisdiction)}. Only 'IN' is supported.`,
    );
  }

  if (!Number.isSafeInteger(input.netAmount) || input.netAmount < 0) {
    throw new TaxComplianceError(
      'netAmount must be a non-negative safe integer expressed in minor units.',
    );
  }

  if (!ALLOWED_TREATMENTS.includes(input.treatment)) {
    throw new TaxComplianceError(
      `Unsupported tax treatment: ${String(input.treatment)}.`,
    );
  }

  if (input.supplierGstin !== undefined) {
    validateGstin(input.supplierGstin);
  }

  if (input.recipientGstin !== undefined) {
    validateGstin(input.recipientGstin);
  }

  if (input.placeOfSupply !== undefined &&
      !ALLOWED_PLACE_OF_SUPPLY.includes(input.placeOfSupply)) {
    throw new TaxComplianceError(
      `Invalid placeOfSupply: ${String(input.placeOfSupply)}. Expected intra-state or inter-state.`,
    );
  }

  if (input.crossBorderDirection !== undefined &&
      !ALLOWED_CROSS_BORDER_DIRECTIONS.includes(input.crossBorderDirection)) {
    throw new TaxComplianceError(
      `Invalid crossBorderDirection: ${String(input.crossBorderDirection)}. Expected export or import.`,
    );
  }

  if ((input.treatment === 'standard' || input.treatment === 'reverse-charge') &&
      !input.placeOfSupply) {
    throw new TaxComplianceError(
      'placeOfSupply is required for standard and reverse-charge supplies.',
    );
  }

  if (input.treatment === 'cross-border' && !input.crossBorderDirection) {
    throw new TaxComplianceError(
      'crossBorderDirection is required for cross-border supplies.',
    );
  }

  if ((input.treatment === 'reverse-charge' ||
        (input.treatment === 'cross-border' &&
         input.crossBorderDirection === 'import')) &&
      !input.recipientGstin) {
    throw new TaxComplianceError(
      'recipientGstin is required for reverse-charge and cross-border import supplies.',
    );
  }
}

function computeDomesticSupplyBreakdown(
  input: TaxInvoiceInput,
  reverseCharge: boolean,
): TaxBreakdown {
  if (!input.placeOfSupply) {
    throw new TaxComplianceError(
      'placeOfSupply is required for domestic supply breakdown.',
    );
  }

  const cgstBasis = reverseCharge
    ? 'CGST Act 2017 s.9(3)/(4) (reverse charge)'
    : 'CGST Act 2017 s.9(1)';
  const sgstBasis = reverseCharge
    ? 'SGST Act s.9(3)/(4) (reverse charge)'
    : 'SGST Act s.9(1)';
  const igstBasis = reverseCharge
    ? 'IGST Act 2017 s.5(3) (reverse charge)'
    : 'IGST Act 2017 s.5(1)';

  const prefix = reverseCharge ? 'RCM-' : '';

  if (input.placeOfSupply === 'intra-state') {
    const cgstAmount = roundTaxAmount(input.netAmount, CGST_RATE_BPS);
    const sgstAmount = roundTaxAmount(input.netAmount, SGST_RATE_BPS);

    return finalizeBreakdown(input, [
      makeTaxHead(
        `${prefix}CGST`,
        CGST_RATE_BPS,
        cgstAmount,
        cgstBasis,
        reverseCharge,
      ),
      makeTaxHead(
        `${prefix}SGST`,
        SGST_RATE_BPS,
        sgstAmount,
        sgstBasis,
        reverseCharge,
      ),
    ], reverseCharge);
  }

  const igstAmount = roundTaxAmount(input.netAmount, IGST_RATE_BPS);
  return finalizeBreakdown(input, [
    makeTaxHead(
      `${prefix}IGST`,
      IGST_RATE_BPS,
      igstAmount,
      igstBasis,
      reverseCharge,
    ),
  ], reverseCharge);
}

function computeCrossBorderBreakdown(input: TaxInvoiceInput): TaxBreakdown {
  if (input.crossBorderDirection === 'export') {
    return finalizeBreakdown(input, [
      makeTaxHead(
        'IGST-ZERO-EXPORT',
        ZERO_RATE_BPS,
        0,
        'IGST Act 2017 s.16(1) (export of services - zero-rated)',
        false,
      ),
    ], false);
  }

  if (input.crossBorderDirection === 'import') {
    const igstAmount = roundTaxAmount(input.netAmount, IGST_RATE_BPS);
    return finalizeBreakdown(input, [
      makeTaxHead(
        'IGST-RCM-IMPORT',
        IGST_RATE_BPS,
        igstAmount,
        'IGST Act 2017 s.5(3) (import of services - reverse charge)',
        true,
      ),
    ], true);
  }

  throw new TaxComplianceError(
    'crossBorderDirection must be export or import for cross-border treatment.',
  );
}

export function computeTaxBreakdown(input: TaxInvoiceInput): TaxBreakdown {
  validateTaxInvoiceInput(input);

  switch (input.treatment) {
    case 'exempt':
      return finalizeBreakdown(input, [
        makeTaxHead(
          'EXEMPT',
          ZERO_RATE_BPS,
          0,
          'CGST Act 2017 s.11 / SGST Act s.11 (exempt supplies)',
          false,
        ),
      ], false);

    case 'zero-rated':
      return finalizeBreakdown(input, [
        makeTaxHead(
          'IGST-ZERO',
          ZERO_RATE_BPS,
          0,
          'IGST Act 2017 s.16(1) (zero-rated supplies)',
          false,
        ),
      ], false);

    case 'cross-border':
      return computeCrossBorderBreakdown(input);

    case 'reverse-charge':
      return computeDomesticSupplyBreakdown(input, true);

    case 'standard':
      return computeDomesticSupplyBreakdown(input, false);

    default:
      throw new TaxComplianceError(
        `Unsupported tax treatment: ${String(input.treatment)}.`,
      );
  }
}