/**
 * Ledger parsing module for comma-separated reference/amount pairs.
 *
 * Example input:
 *   DG0723000255,20000,DG0623000080,935.15
 */
const LEDGER_REFERENCE_PATTERN = /^DG\d{10}$/;
const AMOUNT_PATTERN = /^(0|[1-9]\d*)(\.\d{1,2})?$/;

export class LedgerParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'LedgerParseError';
  }
}

export interface LedgerEntry {
  readonly reference: string;
  readonly amountInCents: number;
}

export interface ProcessedLedger {
  readonly entries: readonly LedgerEntry[];
  readonly totalInCents: number;
}

function assertTrue(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

export function parseAmountToCents(amount: string): number {
  if (typeof amount !== 'string') {
    throw new LedgerParseError('Amount must be a string');
  }

  const trimmed = amount.trim();

  if (!AMOUNT_PATTERN.test(trimmed)) {
    throw new LedgerParseError(`Invalid amount: "${amount}"`);
  }

  const [whole, fraction = ''] = trimmed.split('.');
  const cents = Number(whole) * 100 + Number(fraction.padEnd(2, '0'));

  if (!Number.isSafeInteger(cents)) {
    throw new LedgerParseError(`Amount is too large: "${amount}"`);
  }

  return cents;
}

export function parseLedgerLine(line: string): LedgerEntry[] {
  if (typeof line !== 'string') {
    throw new LedgerParseError('Ledger line must be a string');
  }

  const trimmed = line.trim();

  if (!trimmed) {
    throw new LedgerParseError('Ledger line is empty');
  }

  const rawParts = trimmed.split(',').map((part) => part.trim());

  if (rawParts.length % 2 !== 0) {
    throw new LedgerParseError(
      'Ledger line must contain an even number of comma-separated values',
    );
  }

  const entries: LedgerEntry[] = [];

  for (let index = 0; index < rawParts.length; index += 2) {
    const reference = rawParts[index];
    const amountPart = rawParts[index + 1];

    if (reference === undefined || amountPart === undefined) {
      throw new LedgerParseError('Missing ledger reference or amount');
    }

    if (!LEDGER_REFERENCE_PATTERN.test(reference)) {
      throw new LedgerParseError(`Invalid ledger reference: "${reference}"`);
    }

    entries.push({
      reference,
      amountInCents: parseAmountToCents(amountPart),
    });
  }

  return entries;
}

export function sumLedgerEntries(entries: readonly LedgerEntry[]): number {
  return entries.reduce(
    (total, entry) => total + entry.amountInCents,
    0,
  );
}

export function processLedgerLine(line: string): ProcessedLedger {
  const entries = parseLedgerLine(line);

  return {
    entries,
    totalInCents: sumLedgerEntries(entries),
  };
}

export function formatCentsAsAmount(cents: number): string {
  if (!Number.isInteger(cents)) {
    throw new LedgerParseError(`Cents must be an integer: ${cents}`);
  }

  const sign = cents < 0 ? '-' : '';
  const absoluteCents = Math.abs(cents);
  const whole = Math.floor(absoluteCents / 100);
  const fraction = String(absoluteCents % 100).padStart(2, '0');

  return `${sign}${whole}.${fraction}`;
}

export function runUnitTests(): void {
  console.info('Executing ledger module test suite...');

  const happyPathLine = 'DG0723000255,20000,DG0623000080,935.15';
  const processed = processLedgerLine(happyPathLine);

  assertTrue(
    processed.entries.length === 2,
    'happy path should return two ledger entries',
  );

  const firstEntry = processed.entries[0];
  const secondEntry = processed.entries[1];

  if (!firstEntry || !secondEntry) {
    throw new Error('Expected two ledger entries');
  }

  assertTrue(
    firstEntry.reference === 'DG0723000255',
    'first reference should match',
  );
  assertTrue(
    firstEntry.amountInCents === 2000000,
    'first amount should be 20,000.00 dollars in cents',
  );
  assertTrue(
    secondEntry.reference === 'DG0623000080',
    'second reference should match',
  );
  assertTrue(
    secondEntry.amountInCents === 93515,
    'second amount should be 935.15 dollars in cents',
  );
  assertTrue(
    processed.totalInCents === 2093515,
    'total should be 20,935.15 dollars in cents',
  );
  assertTrue(
    formatCentsAsAmount(processed.totalInCents) === '20935.15',
    'formatted total should match',
  );

  let threwParseError = false;

  try {
    parseLedgerLine('DG0723000255,20000,DG0623000080');
  } catch (error) {
    threwParseError = error instanceof LedgerParseError;
  }

  assertTrue(
    threwParseError,
    'unbalanced ledger line should throw LedgerParseError',
  );

  threwParseError = false;

  try {
    parseAmountToCents('12.345');
  } catch (error) {
    threwParseError = error instanceof LedgerParseError;
  }

  assertTrue(
    threwParseError,
    'invalid amount should throw LedgerParseError',
  );

  threwParseError = false;

  try {
    parseLedgerLine('INVALID,20000,DG0623000080,935.15');
  } catch (error) {
    threwParseError = error instanceof LedgerParseError;
  }

  assertTrue(
    threwParseError,
    'invalid reference should throw LedgerParseError',
  );

  console.info('Ledger module test suite executed successfully.');
}

runUnitTests();