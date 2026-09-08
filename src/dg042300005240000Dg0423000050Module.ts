export interface LedgerEntry {
  reference: string;
  amount: number;
}

export class LedgerParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'LedgerParseError';
  }
}

function splitLedgerInput(input: string): string[] {
  const trimmed = input.trim();

  if (trimmed.length === 0) {
    return [];
  }

  return trimmed
    .split(',')
    .map((part) => part.trim());
}

function parseAmount(rawAmount: string): number {
  const trimmed = rawAmount.trim();

  if (trimmed.length === 0) {
    throw new LedgerParseError('Amount must not be empty');
  }

  const amount = Number(trimmed);

  if (!Number.isFinite(amount)) {
    throw new LedgerParseError(`Amount must be a finite number: ${trimmed}`);
  }

  return amount;
}

export function parseLedgerEntries(input: string): LedgerEntry[] {
  const parts = splitLedgerInput(input);

  if (parts.length === 0) {
    return [];
  }

  if (parts.length % 2 !== 0) {
    throw new LedgerParseError(
      `Expected reference,amount pairs but received ${parts.length} field(s)`,
    );
  }

  const entries: LedgerEntry[] = [];

  for (let index = 0; index < parts.length; index += 2) {
    const reference = parts[index];
    const amountText = parts[index + 1];

    if (reference === undefined || amountText === undefined) {
      throw new LedgerParseError('Unexpected missing field while parsing ledger entries');
    }

    if (reference.length === 0) {
      throw new LedgerParseError(`Reference at position ${index + 1} must not be empty`);
    }

    entries.push({
      reference,
      amount: parseAmount(amountText),
    });
  }

  return entries;
}

export function calculateTotal(entries: ReadonlyArray<LedgerEntry>): number {
  return entries.reduce((total, entry) => total + entry.amount, 0);
}

function assert(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`Self-test failed: ${message}`);
  }
}

export function runSelfTests(): void {
  const happyEntries = parseLedgerEntries('DG0423000052,40000,DG0423000050,40000');

  assert(happyEntries.length === 2, 'happy path should parse two entries');
  assert(happyEntries[0]?.reference === 'DG0423000052', 'first reference should be preserved');
  assert(happyEntries[0]?.amount === 40000, 'first amount should be parsed');
  assert(happyEntries[1]?.reference === 'DG0423000050', 'second reference should be preserved');
  assert(happyEntries[1]?.amount === 40000, 'second amount should be parsed');
  assert(calculateTotal(happyEntries) === 80000, 'happy path should calculate the correct total');

  let failureCaught = false;

  try {
    parseLedgerEntries('DG0423000052,40000,DG0423000050');
  } catch (error) {
    if (error instanceof LedgerParseError) {
      failureCaught = /Expected reference,amount pairs/.test(error.message);
    }
  }

  assert(failureCaught, 'failure path should reject an odd number of fields');

  failureCaught = false;

  try {
    parseLedgerEntries('DG0423000052,not-a-number');
  } catch (error) {
    if (error instanceof LedgerParseError) {
      failureCaught = /finite number/.test(error.message);
    }
  }

  assert(failureCaught, 'failure path should reject a non-numeric amount');
}

runSelfTests();

export default parseLedgerEntries;