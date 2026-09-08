export interface TransactionRecord {
  readonly reference: string;
  readonly amount: number;
}

export const TRANSACTION_INPUT = 'DG0423000054,40000,DG0423000052,40000';

export function parseTransactionLine(input: unknown): TransactionRecord[] {
  if (typeof input !== 'string') {
    throw new TypeError('Transaction input must be a string.');
  }

  const trimmed = input.trim();
  if (trimmed.length === 0) {
    throw new Error('Transaction input must not be empty.');
  }

  const fields = trimmed.split(',').map((field) => field.trim());

  if (fields.some((field) => field.length === 0)) {
    throw new Error('Transaction input contains an empty field between commas.');
  }

  if (fields.length % 2 !== 0) {
    throw new Error(
      `Transaction input must consist of reference/amount pairs, but got ${fields.length} fields.`,
    );
  }

  const records: TransactionRecord[] = [];

  for (let index = 0; index < fields.length; index += 2) {
    const reference = fields[index] as string;
    const amountField = fields[index + 1] as string;

    if (!/^\d+$/.test(amountField)) {
      throw new Error(`Invalid amount at field ${index + 1}: ${amountField}`);
    }

    const amount = Number(amountField);
    if (!Number.isSafeInteger(amount) || amount < 0) {
      throw new Error(`Invalid amount at field ${index + 1}: ${amountField}`);
    }

    records.push({ reference, amount });
  }

  return records;
}

export function dg042300005440000Dg0423000052Module(): TransactionRecord[] {
  return parseTransactionLine(TRANSACTION_INPUT);
}

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${String(expected)}, got ${String(actual)}`);
  }
}

function assertThrows(action: () => unknown, message: string): void {
  let threw = false;

  try {
    action();
  } catch (error) {
    threw = error instanceof Error;
  }

  if (!threw) {
    throw new Error(`${message}: expected an error to be thrown`);
  }
}

export function testHappyPath(): void {
  const records = dg042300005440000Dg0423000052Module();

  if (records.length !== 2) {
    throw new Error(`happy path expected 2 records, got ${records.length}`);
  }

  const first = records[0];
  if (!first) {
    throw new Error('happy path missing first record');
  }

  assertEqual(first.reference, 'DG0423000054', 'first reference mismatch');
  assertEqual(first.amount, 40000, 'first amount mismatch');

  const second = records[1];
  if (!second) {
    throw new Error('happy path missing second record');
  }

  assertEqual(second.reference, 'DG0423000052', 'second reference mismatch');
  assertEqual(second.amount, 40000, 'second amount mismatch');
}

export function testFailurePath(): void {
  assertThrows(
    () => parseTransactionLine('DG0423000054,40000,DG0423000052'),
    'failure path should throw for odd field count',
  );

  assertThrows(
    () => parseTransactionLine('DG0423000054,not-an-amount'),
    'failure path should throw for invalid amount',
  );
}

export function runUnitTests(): void {
  testHappyPath();
  testFailurePath();
}

Deno.test('DG042300005440000Dg0423000052Module happy path', () => {
  testHappyPath();
});

Deno.test('DG042300005440000Dg0423000052Module failure path', () => {
  testFailurePath();
});