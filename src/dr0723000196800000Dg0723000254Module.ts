export interface TransactionEntry {
  readonly reference: string;
  readonly amount: number;
}

export class TransactionParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TransactionParseError';
  }
}

export const DEFAULT_TRANSACTION_INPUT = 'DR0723000196,-800000,DG0723000254,20000';

function parseAmount(rawAmount: string): number {
  const trimmed = rawAmount.trim();
  if (trimmed === '') {
    throw new TransactionParseError('Amount is required');
  }

  const amount = Number(trimmed);
  if (!Number.isFinite(amount)) {
    throw new TransactionParseError(`Amount must be a finite number: "${rawAmount}"`);
  }

  return amount;
}

export function parseTransaction(input: string): TransactionEntry[] {
  if (typeof input !== 'string') {
    throw new TransactionParseError('Transaction input must be a string');
  }

  if (input.trim() === '') {
    throw new TransactionParseError('Transaction input cannot be empty');
  }

  const parts = input.split(',').map((part) => part.trim());
  if (parts.length % 2 !== 0) {
    throw new TransactionParseError(
      `Transaction input must contain reference-amount pairs; received ${parts.length} fields`,
    );
  }

  const entries: TransactionEntry[] = [];
  for (let index = 0; index < parts.length; index += 2) {
    const reference = parts[index];
    const rawAmount = parts[index + 1];

    if (!reference) {
      throw new TransactionParseError(`Missing reference at field position ${index}`);
    }
    if (!rawAmount) {
      throw new TransactionParseError(
        `Missing amount for reference "${reference}" at field position ${index + 1}`,
      );
    }

    entries.push({ reference, amount: parseAmount(rawAmount) });
  }

  return entries;
}

export function sumTransactionAmounts(entries: readonly TransactionEntry[]): number {
  return entries.reduce((total, entry) => total + entry.amount, 0);
}

export function calculateNetPosition(input: string): number {
  return sumTransactionAmounts(parseTransaction(input));
}

export function getDefaultTransactionEntries(): TransactionEntry[] {
  return parseTransaction(DEFAULT_TRANSACTION_INPUT);
}

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${String(expected)}, received ${String(actual)}`);
  }
}

function assertThrowsTransactionParseError(action: () => unknown, message: string): void {
  try {
    action();
  } catch (error) {
    if (error instanceof TransactionParseError) {
      return;
    }

    const detail = error instanceof Error ? error.message : String(error);
    throw new Error(`${message}: expected TransactionParseError, received ${detail}`);
  }

  throw new Error(`${message}: expected action to throw TransactionParseError`);
}

export function testHappyPath(): void {
  const entries = parseTransaction(DEFAULT_TRANSACTION_INPUT);

  assertEqual(entries.length, 2, 'happy path should parse two entries');

  const firstEntry = entries[0];
  if (!firstEntry) {
    throw new Error('happy path: expected first entry to exist');
  }

  const secondEntry = entries[1];
  if (!secondEntry) {
    throw new Error('happy path: expected second entry to exist');
  }

  assertEqual(firstEntry.reference, 'DR0723000196', 'first entry reference');
  assertEqual(firstEntry.amount, -800000, 'first entry amount');
  assertEqual(secondEntry.reference, 'DG0723000254', 'second entry reference');
  assertEqual(secondEntry.amount, 20000, 'second entry amount');
  assertEqual(sumTransactionAmounts(entries), -780000, 'net transaction amount');
}

export function testFailurePath(): void {
  assertThrowsTransactionParseError(
    () => parseTransaction('DR0723000196,not-a-number,DG0723000254,20000'),
    'non-numeric amount',
  );

  assertThrowsTransactionParseError(
    () => parseTransaction('DR0723000196,-800000,DG0723000254'),
    'odd number of fields',
  );
}

export function runSelfTests(): void {
  const testCases: ReadonlyArray<{ name: string; run: () => void }> = [
    { name: 'happy path parses and sums the default transaction', run: testHappyPath },
    { name: 'failure path rejects invalid transaction input', run: testFailurePath },
  ];

  const failures: string[] = [];

  console.log(`Running ${testCases.length} self-test(s)...`);

  for (const testCase of testCases) {
    try {
      testCase.run();
      console.log(`ok - ${testCase.name}`);
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      console.error(`not ok - ${testCase.name}: ${detail}`);
      failures.push(`${testCase.name}: ${detail}`);
    }
  }

  if (failures.length > 0) {
    throw new Error(`${failures.length}/${testCases.length} self-test(s) failed`);
  }

  console.log(`${testCases.length} self-test(s) passed`);
}

export const dr0723000196800000Dg0723000254Module = {
  DEFAULT_TRANSACTION_INPUT,
  parseTransaction,
  sumTransactionAmounts,
  calculateNetPosition,
  getDefaultTransactionEntries,
  testHappyPath,
  testFailurePath,
  runSelfTests,
} as const;

export default dr0723000196800000Dg0723000254Module;

runSelfTests();