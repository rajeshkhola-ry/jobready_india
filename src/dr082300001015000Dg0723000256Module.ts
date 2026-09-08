export interface LedgerEntry {
  readonly debitAccountId: string;
  readonly debitAmount: number;
  readonly creditAccountId: string;
  readonly creditAmount: number;
}

export class LedgerEntryParseError extends Error {
  public readonly field?: string;

  constructor(message: string, field?: string) {
    super(message);
    this.name = 'LedgerEntryParseError';
    this.field = field;
  }
}

const ACCOUNT_ID_PATTERN = /^[A-Za-z]{2}\d{10}$/;

export function isValidAccountId(accountId: string): boolean {
  return ACCOUNT_ID_PATTERN.test(accountId);
}

function parseAmount(amountRaw: string, fieldName: string): number {
  const trimmedAmount = amountRaw.trim();

  if (trimmedAmount === '') {
    throw new LedgerEntryParseError(`${fieldName} must not be empty`, fieldName);
  }

  const amount = Number(trimmedAmount);

  if (!Number.isFinite(amount)) {
    throw new LedgerEntryParseError(`${fieldName} must be a finite number`, fieldName);
  }

  return amount;
}

export function parseLedgerEntry(input: string): LedgerEntry {
  if (typeof input !== 'string') {
    throw new LedgerEntryParseError('Input must be a string');
  }

  const parts = input.split(',');

  if (parts.length !== 4) {
    throw new LedgerEntryParseError(
      `Expected 4 comma-separated fields, received ${parts.length}`,
    );
  }

  const [debitAccountId, debitAmountRaw, creditAccountId, creditAmountRaw] = parts.map(
    (part) => part.trim(),
  );

  if (!isValidAccountId(debitAccountId)) {
    throw new LedgerEntryParseError(
      `Invalid debit account identifier: ${debitAccountId}`,
      'debitAccountId',
    );
  }

  if (!isValidAccountId(creditAccountId)) {
    throw new LedgerEntryParseError(
      `Invalid credit account identifier: ${creditAccountId}`,
      'creditAccountId',
    );
  }

  const debitAmount = parseAmount(debitAmountRaw, 'debitAmount');
  const creditAmount = parseAmount(creditAmountRaw, 'creditAmount');

  return {
    debitAccountId,
    debitAmount,
    creditAccountId,
    creditAmount,
  };
}

export function testHappyPath(): void {
  const entry = parseLedgerEntry('DR0823000010,-15000,DG0723000256,131988.98000000001');

  if (
    entry.debitAccountId !== 'DR0823000010' ||
    entry.debitAmount !== -15000 ||
    entry.creditAccountId !== 'DG0723000256' ||
    entry.creditAmount !== 131988.98000000001
  ) {
    throw new Error('Happy path test failed: parsed entry does not match expected values');
  }
}

export function testFailurePath(): void {
  let caughtError: unknown;

  try {
    parseLedgerEntry('DR0823000010,not-a-number,DG0723000256,131988.98000000001');
  } catch (error) {
    caughtError = error;
  }

  if (!(caughtError instanceof LedgerEntryParseError)) {
    throw new Error('Failure path test failed: expected LedgerEntryParseError');
  }
}

export function runSelfTests(): void {
  testHappyPath();
  testFailurePath();
}