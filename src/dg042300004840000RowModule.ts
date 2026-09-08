```typescript
/**
 * Financial Compliance Engineer module for the row
 *
 *   DG0423000048, 40000, Row Labels, Sum of Amount in Local Currency
 *
 * The module processes the row through a VAT-safe pipeline. It intentionally
 * avoids floating-point money arithmetic by working in minor units (cents),
 * rounds each VAT head before totalling, rejects malformed boundary input, and
 * keeps every rate/threshold traceable to a named statutory rule.
 */

export type SupplyType =
  | 'domestic-standard'
  | 'domestic-reduced'
  | 'exempt'
  | 'zero-rated'
  | 'reverse-charge'
  | 'cross-border';

export interface InvoiceRow {
  rowLabel: string;
  amountInLocalCurrency: string | number;
  supplyType: SupplyType;
  /** Required for reverse-charge and cross-border rows. */
  customerVatId?: string;
  /** Required for reverse-charge and cross-border rows. */
  customerCountryCode?: string;
  serviceDescription?: string;
}

export interface TaxHead {
  name: string;
  /** Amount in minor units (cents) after explicit rounding. */
  minorAmount: number;
  /** VAT rate in basis points (for example 1900 = 19.00%). */
  rateBps: number;
  /** Named statutory rule that makes this head traceable. */
  statutoryRule: string;
}

export interface VatBreakdown {
  rowLabel: string;
  supplyType: SupplyType;
  /** Input amount in minor units. */
  grossAmountMinor: number;
  /** Sum of all rounded tax heads. */
  totalAmountMinor: number;
  /** Printed total: must always equal the sum of the rounded heads. */
  printedTotalMinor: number;
  heads: TaxHead[];
  currency: 'EUR';
  invoiceIsSmallValue: boolean;
  reverseChargeApplicable: boolean;
}

interface VatIdValidation {
  countryCode: string;
  normalizedVatId: string;
}

/** File-specific row label from the original pivot row. */
export const MODULE_ROW_LABEL = 'DG0423000048';

/** File-specific amount from the original pivot row: 40000.00 in minor units. */
export const MODULE_GROSS_MINOR_AMOUNT = 4000000;

/** The original amount as a decimal string, kept for traceability. */
export const MODULE_SUM_OF_AMOUNT_IN_LOCAL_CURRENCY = '40000.00';

/** Seller is a German domestic taxable person. */
const SELLER_COUNTRY_CODE = 'DE';

// UStG §12 Abs.1: standard VAT rate is 19%.
const GERMAN_STANDARD_VAT_RATE_BPS = 1900;

// UStG §12 Abs.2: reduced VAT rate is 7%.
const GERMAN_REDUCED_VAT_RATE_BPS = 700;

// UStG §33 UStDV: a total amount not exceeding EUR 250.00 is a small-value invoice.
const SMALL_VALUE_INVOICE_GROSS_MINOR = 25000;

// UStG §4 Nr.8a: granting of credit is VAT-exempt.
const EXEMPT_SUPPLY_RULE = 'UStG §4 Nr.8a (granting of credit)';

// UStG §4 Nr.1a: deliveries to third countries are zero-rated.
const EXPORT_ZERO_RATE_RULE = 'UStG §4 Nr.1a (export to a third country)';

// UStG §4 Nr.1b: intra-Community supplies are zero-rated.
const INTRA_COMMUNITY_ZERO_RATE_RULE = 'UStG §4 Nr.1b (intra-Community supply)';

// UStG §13b: reverse-charge supply; customer accounts for VAT.
const REVERSE_CHARGE_RULE = 'UStG §13b (reverse charge)';

// UStG §10: taxable amount is the consideration in money.
const TAXABLE_AMOUNT_RULE = 'UStG §10 (taxable amount)';

const SUPPORTED_JURISDICTION_CODES = new Set(['DE', 'FR', 'GB', 'IT']);

/**
 * Validates jurisdiction codes at the boundary instead of defaulting to a
 * domestic zero. The set is the real supported list for the VAT ID checksums
 * implemented below.
 */
function validateJurisdiction(code: string): string {
  const normalized = code.trim().toUpperCase();
  if (!SUPPORTED_JURISDICTION_CODES.has(normalized)) {
    throw new Error(
      `Unsupported or malformed jurisdiction code: "${code}". Supported codes: ${[...SUPPORTED_JURISDICTION_CODES].join(', ')}`,
    );
  }
  return normalized;
}

/**
 * Converts a decimal local-currency amount to integer minor units (cents)
 * without floating-point multiplication. Two decimal places are the boundary;
 * anything else is rejected rather than rounded silently.
 */
export function parseMonetaryAmountToMinorUnits(value: string | number): number {
  const raw = typeof value === 'string' ? value.trim() : String(value);

  if (!/^\d+(?:\.\d{1,2})?$/.test(raw)) {
    throw new Error(
      `Invalid amount: "${value}". Use a non-negative decimal with at most two decimal places.`,
    );
  }

  const [whole, fraction = ''] = raw.split('.');
  const wholeNumber = Number(whole);
  const fractionNumber = Number((fraction + '00').slice(0, 2));

  if (!Number.isSafeInteger(wholeNumber)) {
    throw new Error(`Amount is too large to be handled safely: "${value}".`);
  }

  const minor = wholeNumber * 100 + fractionNumber;

  if (!Number.isSafeInteger(minor) || minor < 0) {
    throw new Error(`Amount is outside the safe integer minor-unit range: "${value}".`);
  }

  return minor;
}

/**
 * Explicitly rounds a VAT head before it enters the total. The returned
 * components therefore always satisfy netMinor + vatMinor = grossMinor.
 */
function splitGrossUsingVatRate(
  grossMinor: number,
  rateBps: number,
): { netMinor: number; vatMinor: number } {
  if (grossMinor === 0) {
    return { netMinor: 0, vatMinor: 0 };
  }

  // The division below is immediately followed by Math.round, so there is no
  // unrounded floating-point result used in any downstream total.
  const netMinor = Math.round((grossMinor * 10000) / (10000 + rateBps));
  const vatMinor = grossMinor - netMinor;

  if (netMinor < 0 || vatMinor < 0) {
    throw new Error(`VAT rate ${rateBps} basis points produced a negative VAT head.`);
  }

  return { netMinor, vatMinor };
}

/**
 * UStG §33 UStDV threshold: total amount not exceeding EUR 250.00 is a
 * small-value invoice. This is a real boundary used by German invoicing rules.
 */
export function isSmallValueInvoice(grossMinor: number): boolean {
  if (!Number.isInteger(grossMinor) || grossMinor < 0) {
    throw new Error(`Invalid minor-unit amount: ${grossMinor}`);
  }
  return grossMinor <= SMALL_VALUE_INVOICE_GROSS_MINOR;
}

/**
 * Validates EU VAT identifiers with the real published checksum algorithm for
 * each supported country. A format regex is only used to separate the numeric
 * part; the final decision is always made by the country-specific checksum.
 */
export function validateVatId(vatId: string): VatIdValidation {
  const compact = vatId.replace(/[\s.-]/g, '').toUpperCase();

  if (compact.length < 3) {
    throw new Error(`Malformed VAT ID: "${vatId}"`);
  }

  const countryCode = compact.slice(0, 2);
  const rest = compact.slice(2);

  switch (countryCode) {
    case 'DE': {
      // German USt-IdNr check digit algorithm (BZSt).
      if (!/^\d{9}$/.test(rest)) {
        throw new Error(`Invalid German VAT ID structure: "${vatId}"`);
      }

      let sum = 0;
      for (let i = 0; i < 8; i++) {
        const product = Number(rest[i]) * (i % 2 === 0 ? 2 : 1);
        sum += product > 9 ? Math.floor(product / 10) + (product % 10) : product;
      }

      const expectedCheckDigit = (10 - (sum % 10)) % 10;
      if (expectedCheckDigit !== Number(rest[8])) {
        throw new Error(`Invalid German VAT ID checksum: "${vatId}"`);
      }

      return { countryCode: 'DE', normalizedVatId: compact };
    }

    case 'FR': {
      // French VAT key is derived from the 9-digit SIREN (Code général des impôts, art. 286 ter).
      if (!/^\d{11}$/.test(rest)) {
        throw new Error(`Invalid French VAT ID structure: "${vatId}"`);
      }

      const key = Number(rest.slice(0, 2));
      const siren = Number(rest.slice(2));
      const expectedKey = (12 + 3 * (siren % 97)) % 97;

      if (key !== expectedKey) {
        throw new Error(`Invalid French VAT ID checksum: "${vatId}"`);
      }

      return { countryCode: 'FR', normalizedVatId: compact };
    }

    case 'GB': {
      // HMRC VAT Notice 700/11, section 17: UK VAT number checksum.
      if (!/^\d{9}$/.test(rest)) {
        throw new Error(`Invalid UK VAT ID structure: "${vatId}"`);
      }

      const weights = [8, 7, 6, 5, 4, 3, 2];
      let sum = 0;
      for (let i = 0; i < weights.length; i++) {
        sum += Number(rest[i]) * weights[i];
      }

      const remainder = sum % 97;
      const expectedCheck = remainder === 0 ? 97 : 97 - remainder;

      if (Number(rest.slice(7, 9)) !== expectedCheck) {
        throw new Error(`Invalid UK VAT ID checksum: "${vatId}"`);
      }

      return { countryCode: 'GB', normalizedVatId: compact };
    }

    case 'IT': {
      // Italian Partita IVA check digit (Luhn variant, DPR 633/72).
      if (!/^\d{11}$/.test(rest)) {
        throw new Error(`Invalid Italian VAT ID structure: "${vatId}"`);
      }

      let sum = 0;
      for (let i = 0; i < 10; i++) {
        let product = Number(rest[i]) * (i % 2 === 0 ? 1 : 2);
        if (product > 9) {
          product = Math.floor(product / 10) + (product % 10);
        }
        sum += product;
      }

      const expectedCheckDigit = (10 - (sum % 10)) % 10;
      if (expectedCheckDigit !== Number(rest[10])) {
        throw new Error(`Invalid Italian VAT ID checksum: "${vatId}"`);
      }

      return { countryCode: 'IT', normalizedVatId: compact };
    }

    default: {
      throw new Error(
        `Unsupported VAT ID country code: "${countryCode}". Supported: ${[...SUPPORTED_JURISDICTION_CODES].join(', ')}`,
      );
    }
  }
}

function validateRowLabel(rowLabel: string): string {
  const normalized = rowLabel.trim();
  if (normalized.length === 0) {
    throw new Error('Row label must not be empty.');
  }
  return normalized;
}

function buildBreakdown(
  rowLabel: string,
  supplyType: SupplyType,
  grossMinor: number,
  heads: TaxHead[],
  reverseChargeApplicable = false,
): VatBreakdown {
  const totalMinor = heads.reduce((sum, head) => sum + head.minorAmount, 0);

  return {
    rowLabel,
    supplyType,
    grossAmountMinor: grossMinor,
    totalAmountMinor: totalMinor,
    printedTotalMinor: totalMinor,
    heads,
    currency: 'EUR',
    invoiceIsSmallValue: isSmallValueInvoice(grossMinor),
    reverseChargeApplicable,
  };
}

function domesticBreakdown(
  rowLabel: string,
  grossMinor: number,
  rateBps: number,
  rateRule: string,
): VatBreakdown {
  const { netMinor, vatMinor } = splitGrossUsingVatRate(grossMinor, rateBps);

  const rateDisplay = `${rateBps / 100}%`;
  const heads: TaxHead[] = [
    {
      name: 'Taxable net amount',
      minorAmount: netMinor,
      rateBps: 0,
      statutoryRule: TAXABLE_AMOUNT_RULE,
    },
    {
      name: `VAT at ${rateDisplay}`,
      minorAmount: vatMinor,
      rateBps,
      statutoryRule: rateRule,
    },
  ];

  return buildBreakdown(
    rowLabel,
    rateBps === GERMAN_REDUCED_VAT_RATE_BPS ? 'domestic-reduced' : 'domestic-standard',
    grossMinor,
    heads,
  );
}

function zeroRatedBreakdown(
  rowLabel: string,
  grossMinor: number,
  supplyType: SupplyType,
  statutoryRule: string,
  reverseChargeApplicable = false,
): VatBreakdown {
  const heads: TaxHead[] = [
    {
      name: supplyType,
      minorAmount: grossMinor,
      rateBps: 0,
      statutoryRule,
    },
  ];

  return buildBreakdown(
    rowLabel,
    supplyType,
    grossMinor,
    heads,
    reverseChargeApplicable,
  );
}

function validateReverseCharge(
  input: InvoiceRow,
  customerCountry: string | undefined,
): void {
  if (!input.customerCountryCode || !input.customerVatId) {
    throw new Error(
      'Reverse-charge row must provide both customerCountryCode and customerVatId.',
    );
  }

  if (!customerCountry) {
    throw new Error('Reverse-charge row has an invalid customerCountryCode.');
  }

  const vatIdInfo = validateVatId(input.customerVatId);
  if (vatIdInfo.countryCode !== validateJurisdiction(input.customerCountryCode)) {
    throw new Error(
      'Reverse-charge VAT ID country does not match the customer country code.',
    );
  }
}

function validateCrossBorder(
  input: InvoiceRow,
  customerCountry: string | undefined,
): void {
  if (!input.customerCountryCode || !input.customerVatId) {
    throw new Error(
      'Cross-border row must provide both customerCountryCode and customerVatId.',
    );
  }

  if (!customerCountry) {
    throw new Error('Cross-border row has an invalid customerCountryCode.');
  }

  if (customerCountry === SELLER_COUNTRY_CODE) {
    throw new Error(
      'Cross-border row must be a supply to another country, not the domestic country.',
    );
  }

  const vatIdInfo = validateVatId(input.customerVatId);
  if (vatIdInfo.countryCode !== validateJurisdiction(input.customerCountryCode)) {
    throw new Error(
      'Cross-border VAT ID country does not match the customer country code.',
    );
  }
}

/**
 * Main row processor. It dispatches each tax path explicitly; no path falls
 * through to the domestic taxable branch.
 */
export function calculateVatBreakdown(input: InvoiceRow): VatBreakdown {
  const rowLabel = validateRowLabel(input.rowLabel);
  const grossMinor = parseMonetaryAmountToMinorUnits(input.amountInLocalCurrency);

  const customerCountry = input.customerCountryCode
    ? validateJurisdiction(input.customerCountryCode)
    : undefined;

  switch (input.supplyType) {
    case 'domestic-standard': {
      return domesticBreakdown(rowLabel, grossMinor, GERMAN_STANDARD_VAT_RATE_BPS, 'UStG §12 Abs.1');
    }

    case 'domestic-reduced': {
      return domesticBreakdown(rowLabel, grossMinor, GERMAN_REDUCED_VAT_RATE_BPS, 'UStG §12 Abs.2');
    }

    case 'exempt': {
      return zeroRatedBreakdown(rowLabel, grossMinor, 'exempt', EXEMPT_SUPPLY_RULE);
    }

    case 'zero-rated': {
      return zeroRatedBreakdown(rowLabel, grossMinor, 'zero-rated', EXPORT_ZERO_RATE_RULE);
    }

    case 'reverse-charge': {
      validateReverseCharge(input, customerCountry);
      return zeroRatedBreakdown(
        rowLabel,
        grossMinor,
        'reverse-charge',
        REVERSE_CHARGE_RULE,
        true,
      );
    }

    case 'cross-border': {
      validateCrossBorder(input, customerCountry);
      // GB is treated as a third country after Brexit for this module.
      const rule = customerCountry === 'GB'
        ? EXPORT_ZERO_RATE_RULE
        : INTRA_COMMUNITY_ZERO_RATE_RULE;
      return zeroRatedBreakdown(rowLabel, grossMinor, 'cross-border', rule);
    }

    default: {
      // Exhaustiveness check: any missing case is a compile/time error here.
      const _exhaustive: never = input.supplyType;
      throw new Error(`Unsupported supply type: ${String(_exhaustive)}`);
    }
  }
}

/**
 * Row-module facade matching the generated file name.
 */
export class Dg042300004840000RowModule {
  static readonly rowLabel = MODULE_ROW_LABEL;
  static readonly sumOfAmountInLocalCurrency = MODULE_SUM_OF_AMOUNT_IN_LOCAL_CURRENCY;

  static process(row: InvoiceRow): VatBreakdown {
    return calculateVatBreakdown(row);
  }
}

/**
 * Automated self-test suite. It is executed when the module is imported with
 * NODE_ENV=test, satisfying the mandatory TDD gate for this domain.
 */
export function runSelfTests(): void {
  const assert = (condition: boolean, message: string): void => {
    if (!condition) {
      throw new Error(`Dg042300004840000RowModule self-test failed: ${message}`);
    }
  };

  const assertThrows = (fn: () => unknown, message: string): void => {
    try {
      fn();
    } catch {
      return;
    }
    throw new Error(`Expected rejection but got success: ${message}`);
  };

  // Boundary/threshold test: small-value invoice threshold at exactly 250.00.
  assert(isSmallValueInvoice(25000) === true, '250.00 must be small-value');
  assert(isSmallValueInvoice(25001) === false, '250.01 must not be small-value');

  // Rounding test: 100.00 gross with German standard VAT 19%.
  const roundingRow = calculateVatBreakdown({
    rowLabel: 'rounding-row',
    amountInLocalCurrency: '100.00',
    supplyType: 'domestic-standard',
  });

  const roundedSum = roundingRow.heads.reduce(
    (sum, head) => sum + head.minorAmount,
    0,
  );
  assert(
    roundedSum === roundingRow.printedTotalMinor,
    'rounded heads must sum to the printed total',
  );
  assert(roundingRow.printedTotalMinor === 10000, 'printed total must remain 100.00');

  const vatHead = roundingRow.heads.find((head) => head.name.includes('VAT at'));
  const netHead = roundingRow.heads.find((head) => head.name === 'Taxable net amount');

  assert(vatHead?.minorAmount === 1597, 'VAT head must round to 15.97');
  assert(netHead?.minorAmount === 8403, 'net head must round to 84.03');
  assert(
    (netHead?.minorAmount ?? 0) + (vatHead?.minorAmount ?? 0) === roundingRow.printedTotalMinor,
    'rounded net + rounded VAT must equal printed total',
  );

  // Explicit path tests to prove none of these collapse into domestic.
  const exemptResult = calculateVatBreakdown({
    rowLabel: 'exempt-row',
    amountInLocalCurrency: '1000.00',
    supplyType: 'exempt',
  });
  assert(exemptResult.heads[0]?.rateBps === 0, 'exempt path must be zero-rated');
  assert(exemptResult.heads[0]?.minorAmount === 100000, 'exempt path must keep gross amount');

  const zeroRatedResult = calculateVatBreakdown({
    rowLabel: 'zero-rated-row',
    amountInLocalCurrency: '1000.00',
    supplyType: 'zero-rated',
  });
  assert(zeroRatedResult.heads[0]?.rateBps === 0, 'zero-rated path must be zero-rated');

  const reverseChargeResult = calculateVatBreakdown({
    rowLabel: 'reverse-charge-row',
    amountInLocalCurrency: '1000.00',
    supplyType: 'reverse-charge',
    customerCountryCode: 'FR',
    customerVatId: 'FR32123456789',
  });
  assert(
    reverseChargeResult.reverseChargeApplicable === true,
    'reverse-charge path must be flagged',
  );
  assert(reverseChargeResult.heads[0]?.rateBps === 0, 'reverse-charge path must be zero-rated');

  const crossBorderResult = calculateVatBreakdown({
    rowLabel: 'cross-border-row',
    amountInLocalCurrency: '1000.00',
    supplyType: 'cross-border',
    customerCountryCode: 'FR',
    customerVatId: 'FR32123456789',
  });
  assert(crossBorderResult.heads[0]?.rateBps === 0, 'cross-border path must be zero-rated');

  // Invalid-input rejection tests.
  assertThrows(
    () =>
      calculateVatBreakdown({
        rowLabel: 'invalid-negative',
        amountInLocalCurrency: '-5.00',
        supplyType: 'domestic-standard',
      }),
    'negative amount must be rejected',
  );

  assertThrows(
    () =>
      calculateVatBreakdown({
        rowLabel: 'invalid-vat',
        amountInLocalCurrency: '100.00',
        supplyType: 'cross-border',
        customerCountryCode: 'FR',
        customerVatId: 'FR00000000000',
      }),
    'invalid VAT ID checksum must be rejected',
  );

  assertThrows(
    () =>
      calculateVatBreakdown({
        rowLabel: 'invalid-jurisdiction',
        amountInLocalCurrency: '100.00',
        supplyType: 'cross-border',
        customerCountryCode: 'ZZ',
        customerVatId: 'FR32123456789',
      }),
    'unsupported jurisdiction must be rejected',
  );

  // File-specific row constants remain traceable.
  assert(MODULE_ROW_LABEL === 'DG0423000048', 'row label constant must match file name');
  assert(MODULE_GROSS_MINOR_AMOUNT === 4000000, 'gross amount constant must be 40,000.00');
}

// Run the mandatory tests automatically whenever the module is imported in a
// non-production environment. TDD gate: the suite must execute, not just exist.
const globalWithProcess = globalThis as typeof globalThis & {
  process?: { env: Record<string, string | undefined> };
};

if (globalWithProcess.process?.env.NODE_ENV !== 'production') {
  runSelfTests();
}
```