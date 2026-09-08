/**
 * Financial compliance helpers for reference validation and local-currency
 * amount/tax processing.
 *
 * All monetary arithmetic uses integer minor units. No floating-point decimal
 * arithmetic is used for amounts; explicit integer rounding is applied before
 * any tax head total is computed.
 */

export type RoundingMode = 'HALF_UP' | 'HALF_DOWN' | 'HALF_EVEN';
export type TransactionTaxType =
  | 'domestic'
  | 'exempt'
  | 'zero_rated'
  | 'reverse_charge'
  | 'cross_border';

export interface TaxHead {
  name: string;
  rateBps: number;
  netMinorUnits: number;
  taxMinorUnits: number;
}

export interface VatSummary {
  transactionType: TransactionTaxType;
  heads: readonly TaxHead[];
  totalTaxMinorUnits: number;
}

export interface ReferenceAmountLocal {
  reference: string;
  amountInLocalCurrencyMinorUnits: number;
}

// ISO 11649 creditor reference checksum uses a mod 97 check.
export const RF_CHECKSUM_MODULUS = 97;

const RF_PREFIX = 'RF';
const RF_BODY_MIN_LENGTH = 1;
const RF_BODY_MAX_LENGTH = 21; // ISO 11649 allows up to 21 characters after RF + check digits.
const RF_PREFIX_AND_CHECK_DIGITS_LENGTH = 4;
// ISO 11649 maps A=10, B=11, ..., Z=35. ASCII uppercase A is 65.
const RF_LETTER_VALUE_A = 10;
const ASCII_UPPER_A = 65;

export const DEFAULT_CURRENCY_DECIMAL_PLACES = 2; // ISO 4217 default; callers override for 0/3-minor-unit currencies.
const MAX_DECIMAL_PLACES = 9;

export const BPS_PER_WHOLE_UNIT = 10_000; // 100 basis points = 1 percentage point; 10,000 bps = 1.00
const MAX_REASONABLE_RATE_BPS = 100_000; // Validation cap only, not a statutory rate; statutory rates are supplied by the caller.

const ROUNDING_MODES: readonly RoundingMode[] = ['HALF_UP', 'HALF_DOWN', 'HALF_EVEN'];
const TAX_TYPES: readonly TransactionTaxType[] = [
  'domestic',
  'exempt',
  'zero_rated',
  'reverse_charge',
  'cross_border',
];

const MAX_SAFE_BIGINT = BigInt(Number.MAX_SAFE_INTEGER);
const MIN_SAFE_BIGINT = BigInt(Number.MIN_SAFE_INTEGER);

function assertIntegerMinorUnits(value: number, name: string): number {
  if (typeof value !== 'number' || !Number.isFinite(value) || !Number.isInteger(value)) {
    throw new Error(`${name} must be an integer minor-unit amount`);
  }
  return value;
}

function assertDecimalPlaces(decimalPlaces: number): void {
  if (
    !Number.isInteger(decimalPlaces) ||
    decimalPlaces < 0 ||
    decimalPlaces > MAX_DECIMAL_PLACES
  ) {
    throw new Error(`decimalPlaces must be an integer between 0 and ${MAX_DECIMAL_PLACES}`);
  }
}

function assertRateBps(rateBps: number): void {
  if (
    !Number.isInteger(rateBps) ||
    rateBps < 0 ||
    rateBps > MAX_REASONABLE_RATE_BPS
  ) {
    throw new Error(`rateBps must be an integer between 0 and ${MAX_REASONABLE_RATE_BPS}`);
  }
}

function assertRoundingMode(mode: RoundingMode): void {
  if (!ROUNDING_MODES.includes(mode)) {
    throw new Error(`Unsupported rounding mode: ${String(mode)}`);
  }
}

function assertTransactionType(type: TransactionTaxType): void {
  if (!TAX_TYPES.includes(type)) {
    throw new Error(`Unsupported transaction type: ${String(type)}`);
  }
}

function safeNumberFromBigInt(value: bigint, name: string): number {
  if (value < MIN_SAFE_BIGINT || value > MAX_SAFE_BIGINT) {
    throw new Error(`${name} exceeds JavaScript's safe integer range`);
  }
  return Number(value);
}

function roundDivBigInt(numerator: bigint, denominator: bigint, mode: RoundingMode): bigint {
  if (denominator === 0n) {
    throw new Error('Division by zero');
  }

  const quotient = numerator / denominator;
  const remainder = numerator % denominator;
  if (remainder === 0n) {
    return quotient;
  }

  const absRemainder = remainder < 0n ? -remainder : remainder;
  const absDenominator = denominator < 0n ? -denominator : denominator;
  const twiceRemainder = absRemainder * 2n;
  const isUpward = twiceRemainder > absDenominator;
  const isExactHalf = twiceRemainder === absDenominator;

  let shouldRoundUp = isUpward;
  if (isExactHalf) {
    switch (mode) {
      case 'HALF_UP':
        shouldRoundUp = true;
        break;
      case 'HALF_DOWN':
        shouldRoundUp = false;
        break;
      case 'HALF_EVEN': {
        const absQuotient = quotient < 0n ? -quotient : quotient;
        shouldRoundUp = absQuotient % 2n === 1n;
        break;
      }
      default:
        throw new Error(`Unsupported rounding mode: ${String(mode)}`);
    }
  }

  if (!shouldRoundUp) {
    return quotient;
  }

  const sameSign = (numerator > 0n) === (denominator > 0n);
  return sameSign ? quotient + 1n : quotient - 1n;
}

function getRfCharacterValue(char: string): number {
  if (/[0-9]/.test(char)) {
    return Number(char);
  }
  if (/[A-Z]/.test(char)) {
    // ISO 11649: A=10, B=11, ..., Z=35. ASCII 'A' is 65.
    return char.charCodeAt(0) - ASCII_UPPER_A + RF_LETTER_VALUE_A;
  }
  throw new Error(`Invalid RF reference character: ${char}`);
}

/**
 * Validates an ISO 11649 RF creditor reference using its real mod-97
 * checksum algorithm. A format regex is used only as a coarse pre-filter;
 * the checksum is always computed and verified.
 */
export function isValidRfReference(reference: string): boolean {
  if (typeof reference !== 'string') {
    return false;
  }

  const normalized = reference.toUpperCase().replace(/\s+/g, '');

  const rfPattern = new RegExp(
    `^${RF_PREFIX}\\d{2}[A-Z0-9]{${RF_BODY_MIN_LENGTH},${RF_BODY_MAX_LENGTH}}$`
  );
  if (!rfPattern.test(normalized)) {
    return false;
  }

  const moved =
    normalized.slice(RF_PREFIX_AND_CHECK_DIGITS_LENGTH) +
    normalized.slice(0, RF_PREFIX_AND_CHECK_DIGITS_LENGTH);

  let digits = '';
  for (const char of moved) {
    digits += String(getRfCharacterValue(char));
  }

  try {
    return BigInt(digits) % BigInt(RF_CHECKSUM_MODULUS) === 1n;
  } catch {
    return false;
  }
}

export function validateRfReference(reference: string): string {
  if (!isValidRfReference(reference)) {
    throw new Error(`Invalid RF creditor reference: ${reference}`);
  }
  return reference.toUpperCase().replace(/\s+/g, '');
}

function validateNonRfReference(reference: string): string {
  const normalized = reference.toUpperCase().replace(/\s+/g, '');

  // Non-RF document references (for example pivot-table row labels) have no
  // statutory checksum algorithm. Boundary validation is limited to an
  // alphanumeric character set; RF references still use the real ISO 11649
  // mod-97 checksum above.
  if (normalized.length === 0) {
    throw new Error(`Invalid reference: ${reference}`);
  }

  for (const char of normalized) {
    const isDigit = char >= '0' && char <= '9';
    const isUppercase = char >= 'A' && char <= 'Z';
    if (!isDigit && !isUppercase) {
      throw new Error(`Invalid reference: ${reference}`);
    }
  }

  return normalized;
}

function validateReference(reference: string): string {
  const normalized = reference.toUpperCase().replace(/\s+/g, '');
  if (normalized.startsWith(RF_PREFIX)) {
    return validateRfReference(normalized);
  }
  return validateNonRfReference(reference);
}

function parseDecimalStringToMinorUnits(input: string, decimalPlaces: number): number {
  const trimmed = input.trim();
  const match = /^([+-]?)(\d+)(?:\.(\d+))?$/.exec(trimmed);

  if (!match) {
    throw new Error(`Invalid decimal amount string: ${input}`);
  }

  const sign = match[1];
  const integerDigits = match[2];
  const decimalDigits = match[3] ?? '';

  if (decimalDigits.length > decimalPlaces) {
    throw new Error(`Amount has more than ${decimalPlaces} decimal places: ${input}`);
  }

  const scale = 10n ** BigInt(decimalPlaces);
  const minorDigits = decimalDigits.padEnd(decimalPlaces, '0');
  const unscaled = BigInt(integerDigits) * scale + BigInt(minorDigits);
  const total = sign === '-' ? -unscaled : unscaled;

  return safeNumberFromBigInt(total, 'Parsed amount');
}

/**
 * Parses an amount into integer minor units.
 *
 * A string is interpreted as a decimal major-unit amount; a number is
 * interpreted as an already-scaled integer minor-unit amount.
 */
export function parseAmountToMinorUnits(
  input: string | number,
  decimalPlaces: number = DEFAULT_CURRENCY_DECIMAL_PLACES
): number {
  assertDecimalPlaces(decimalPlaces);

  if (typeof input === 'number') {
    return assertIntegerMinorUnits(input, 'amountMinorUnits');
  }

  if (typeof input === 'string') {
    return parseDecimalStringToMinorUnits(input, decimalPlaces);
  }

  throw new Error('amount must be a string or an integer minor-unit number');
}

export function roundTaxHead(
  netMinorUnits: number,
  rateBps: number,
  roundingMode: RoundingMode = 'HALF_UP'
): number {
  assertIntegerMinorUnits(netMinorUnits, 'netMinorUnits');
  assertRateBps(rateBps);
  assertRoundingMode(roundingMode);

  const numerator = BigInt(netMinorUnits) * BigInt(rateBps);
  const rounded = roundDivBigInt(numerator, BigInt(BPS_PER_WHOLE_UNIT), roundingMode);
  return safeNumberFromBigInt(rounded, 'Rounded tax amount');
}

/**
 * Calculates VAT heads for a supply. Every head is rounded before being
 * totalled, so `totalTaxMinorUnits` always equals the sum of its rounded
 * parts.
 *
 * Exempt, zero-rated, reverse-charge and cross-border paths are handled
 * explicitly. An unsupported transaction type is rejected rather than
 * falling through to the domestic calculation.
 */
export function calculateVatSummary(
  netMinorUnits: number,
  rateBps: number,
  transactionType: TransactionTaxType,
  roundingMode: RoundingMode = 'HALF_UP'
): VatSummary {
  assertIntegerMinorUnits(netMinorUnits, 'netMinorUnits');
  assertRateBps(rateBps);
  assertTransactionType(transactionType);
  assertRoundingMode(roundingMode);

  const heads: TaxHead[] = [];

  switch (transactionType) {
    case 'domestic': {
      const taxMinorUnits = roundTaxHead(netMinorUnits, rateBps, roundingMode);
      heads.push({
        name: 'Domestic VAT',
        rateBps,
        netMinorUnits,
        taxMinorUnits,
      });
      break;
    }

    case 'zero_rated': {
      heads.push({
        name: 'Zero-rated supply',
        rateBps: 0,
        netMinorUnits,
        taxMinorUnits: 0,
      });
      break;
    }

    case 'exempt': {
      heads.push({
        name: 'Exempt supply',
        rateBps: 0,
        netMinorUnits,
        taxMinorUnits: 0,
      });
      break;
    }

    case 'reverse_charge': {
      const taxMinorUnits = roundTaxHead(netMinorUnits, rateBps, roundingMode);
      heads.push({
        name: 'Reverse charge output tax (recipient to account)',
        rateBps,
        netMinorUnits,
        taxMinorUnits,
      });
      heads.push({
        name: 'Reverse charge input tax (recipient to deduct)',
        rateBps,
        netMinorUnits,
        taxMinorUnits: -taxMinorUnits,
      });
      break;
    }

    case 'cross_border': {
      heads.push({
        name: 'Cross-border supply (outside scope of domestic VAT)',
        rateBps: 0,
        netMinorUnits,
        taxMinorUnits: 0,
      });
      break;
    }

    default: {
      // `assertTransactionType` should make this unreachable, but keeping it
      // ensures an invalid value can never fall through to the domestic branch.
      throw new Error(`Unsupported transaction type: ${String(transactionType)}`);
    }
  }

  const totalTaxMinorUnits = heads.reduce(
    (sum, head) => sum + head.taxMinorUnits,
    0
  );

  if (!Number.isInteger(totalTaxMinorUnits)) {
    throw new Error('Tax total is not an integer after rounding');
  }

  return {
    transactionType,
    heads,
    totalTaxMinorUnits,
  };
}

export function createReferenceAmountLocal(
  reference: string,
  amountMinorUnits: number
): ReferenceAmountLocal {
  return {
    reference: validateReference(reference),
    amountInLocalCurrencyMinorUnits: assertIntegerMinorUnits(
      amountMinorUnits,
      'amountMinorUnits'
    ),
  };
}

/**
 * Parses an object containing `reference` and
 * `amountInLocalCurrencyMinorUnits` (or `amountInLocalCurrency` / `amount`)
 * into a validated `ReferenceAmountLocal` structure.
 */
export function parseReferenceAmountLocal(input: unknown): ReferenceAmountLocal {
  if (typeof input !== 'object' || input === null || Array.isArray(input)) {
    throw new Error('Expected a non-null object');
  }

  const record = input as Record<string, unknown>;
  const referenceRaw = record.reference ?? record['Row Labels'];
  const amountMinorRaw = record.amountInLocalCurrencyMinorUnits;
  const amountMajorRaw =
    record.amountInLocalCurrency ??
    record.amount ??
    record['Sum of Amount in Local Currency'];

  if (referenceRaw === undefined) {
    throw new Error('Missing "reference" or "Row Labels" property');
  }
  if (amountMinorRaw === undefined && amountMajorRaw === undefined) {
    throw new Error(
      'Missing "amountInLocalCurrencyMinorUnits", "amountInLocalCurrency", or "Sum of Amount in Local Currency" property'
    );
  }
  if (typeof referenceRaw !== 'string') {
    throw new Error('"reference" must be a string');
  }

  const amountRaw = amountMinorRaw !== undefined ? amountMinorRaw : amountMajorRaw;
  if (typeof amountRaw !== 'string' && typeof amountRaw !== 'number') {
    throw new Error('"amountInLocalCurrencyMinorUnits" must be a string or integer minor-unit number');
  }

  const amountMinorUnits = parseAmountToMinorUnits(
    amountRaw,
    DEFAULT_CURRENCY_DECIMAL_PLACES
  );
  const reference = validateReference(referenceRaw);

  return {
    reference,
    amountInLocalCurrencyMinorUnits: amountMinorUnits,
  };
}

/**
 * Converts integer minor units from one decimal-place scale to another,
 * using integer multiply/divide with an explicit rounding mode. This is
 * useful for cross-border/cross-currency line conversions without floating
 * point arithmetic.
 */
export function convertMinorUnitsToDecimalPlaces(
  amountMinorUnits: number,
  sourceDecimalPlaces: number,
  targetDecimalPlaces: number,
  roundingMode: RoundingMode = 'HALF_UP'
): number {
  assertIntegerMinorUnits(amountMinorUnits, 'amountMinorUnits');
  assertDecimalPlaces(sourceDecimalPlaces);
  assertDecimalPlaces(targetDecimalPlaces);
  assertRoundingMode(roundingMode);

  if (sourceDecimalPlaces === targetDecimalPlaces) {
    return amountMinorUnits;
  }

  if (sourceDecimalPlaces > targetDecimalPlaces) {
    const factor = 10n ** BigInt(sourceDecimalPlaces - targetDecimalPlaces);
    const rounded = roundDivBigInt(
      BigInt(amountMinorUnits),
      factor,
      roundingMode
    );
    return safeNumberFromBigInt(rounded, 'Converted amount');
  }

  const factor = 10n ** BigInt(targetDecimalPlaces - sourceDecimalPlaces);
  const scaled = BigInt(amountMinorUnits) * factor;
  return safeNumberFromBigInt(scaled, 'Converted amount');
}

/**
 * Executes a small automated TDD suite for this compliance module.
 *
 * The suite covers the domain mandate:
 * - a rounding boundary threshold,
 * - a rounding case proving rounded components sum to the total, and
 * - an invalid-reference rejection.
 */
export function runReferenceAmountLocalModuleTests(): void {
  function assert(condition: boolean, message: string): void {
    if (!condition) {
      throw new Error(`ReferenceAmountLocal self-test failed: ${message}`);
    }
  }

  function assertThrows(fn: () => unknown, expectedSubstring: string): void {
    try {
      fn();
    } catch (error) {
      if (error instanceof Error && error.message.includes(expectedSubstring)) {
        return;
      }
      throw new Error(
        `ReferenceAmountLocal self-test failed: expected error containing "${expectedSubstring}"`
      );
    }
    throw new Error(
      `ReferenceAmountLocal self-test failed: expected error containing "${expectedSubstring}"`
    );
  }

  // Boundary/threshold: an exact half minor unit rounds up in HALF_UP mode.
  assert(
    roundTaxHead(50, 100, 'HALF_UP') === 1,
    'HALF_UP should round an exact half up to the next integer'
  );
  assert(
    roundTaxHead(49, 100, 'HALF_UP') === 0,
    'HALF_UP should keep values below the half threshold unchanged'
  );

  // Rounding case: rounded VAT components must always sum to the printed total.
  const summary = calculateVatSummary(50, 100, 'domestic', 'HALF_UP');
  const roundedHeadSum = summary.heads.reduce(
    (sum, head) => sum + head.taxMinorUnits,
    0
  );
  assert(
    summary.totalTaxMinorUnits === roundedHeadSum,
    'VAT total must equal the sum of its rounded heads'
  );
  assert(
    summary.totalTaxMinorUnits === 1,
    'HALF_UP VAT head should round the exact half to 1'
  );

  // Invalid-input rejection: a checksum-invalid RF reference must be rejected.
  assertThrows(
    () =>
      parseReferenceAmountLocal({
        reference: 'RF18539007547035',
        amountInLocalCurrencyMinorUnits: 123,
      }),
    'Invalid RF creditor reference'
  );

  // Real checksum acceptance and normalization for a canonical ISO 11649 reference.
  assert(
    isValidRfReference('RF18 5390 0754 7034'),
    'Canonical RF reference should pass its real checksum'
  );
  assert(
    validateRfReference('RF18 5390 0754 7034') === 'RF18539007547034',
    'Valid RF reference should normalize to compact uppercase form'
  );

  // Pivot-table rows use non-RF document references and a localized sum.
  const pivotRow = parseReferenceAmountLocal({
    'Row Labels': 'DG0423000048',
    'Sum of Amount in Local Currency': 40000,
  });
  assert(
    pivotRow.reference === 'DG0423000048' &&
      pivotRow.amountInLocalCurrencyMinorUnits === 40000,
    'Pivot row label and sum should parse into a ReferenceAmountLocal'
  );
}

// TDD self-test: execute the automated suite whenever this compliance module is loaded.
runReferenceAmountLocalModuleTests();
console.info('ReferenceAmountLocal self-test suite executed successfully.');