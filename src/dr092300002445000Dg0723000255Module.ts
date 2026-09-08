import { test } from 'node:test';
import { strict as assert } from 'node:assert';

export interface TransactionRecord {
  id: string;
  amount: number;
}

export interface ParsedTransaction {
  records: TransactionRecord[];
  netAmount: number;
  source: string;
}

export class TransactionParseError extends Error {
  public constructor(message: string, public readonly input?: string) {
    super(message);
    this.name = 'TransactionParseError';
  }
}

export const DEFAULT_TRANSACTION_INPUT = 'DR0923000024,-45000,DG0723000255,20000';

export function sumAmounts(records: readonly TransactionRecord[]): number {
  return records.reduce((total, record) => total + record.amount, 0);
}

export function parseTransaction(input: string): ParsedTransaction {
  const trimmed = input.trim();
  if (trimmed.length === 0) {
    throw new TransactionParseError('Transaction input must not be empty.', input);
  }

  const tokens = trimmed.split(',').map((token) => token.trim());
  if (tokens.length % 2 !== 0) {
    throw new TransactionParseError(
      `Expected an even number of comma-separated values, but received ${tokens.length}.`,
      input,
    );
  }

  const records: TransactionRecord[] = [];
  for (let index = 0; index < tokens.length; index += 2) {
    const idToken = tokens[index];
    const amountToken = tokens[index + 1];

    if (idToken === undefined || idToken.length === 0) {
      throw new TransactionParseError(`Missing transaction id at position ${index + 1}.`, input);
    }

    if (amountToken === undefined || amountToken.length === 0) {
      throw new TransactionParseError(`Missing amount for transaction id "${idToken}".`, input);
    }

    const amount = Number(amountToken);
    if (!Number.isFinite(amount)) {
      throw new TransactionParseError(
        `Invalid amount "${amountToken}" for transaction id "${idToken}".`,
        input,
      );
    }

    records.push({ id: idToken, amount });
  }

  return {
    records,
    netAmount: sumAmounts(records),
    source: input,
  };
}

export function dr092300002445000Dg0723000255Module(
  input: string = DEFAULT_TRANSACTION_INPUT,
): ParsedTransaction {
  return parseTransaction(input);
}

export default dr092300002445000Dg0723000255Module;

function assertCondition(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function assertThrows(
  fn: () => unknown,
  predicate: (error: unknown) => boolean,
  message: string,
): void {
  try {
    fn();
  } catch (error) {
    if (predicate(error)) {
      return;
    }
    throw new Error(`Assertion failed: ${message}; received ${String(error)}`);
  }
  throw new Error(`Assertion failed: ${message}; expected function to throw`);
}

export function runSelfTests(): void {
  const parsed = parseTransaction(DEFAULT_TRANSACTION_INPUT);
  const first = parsed.records[0];
  const second = parsed.records[1];

  assertCondition(
    parsed.records.length === 2 &&
      first !== undefined &&
      first.id === 'DR0923000024' &&
      first.amount === -45000 &&
      second !== undefined &&
      second.id === 'DG0723000255' &&
      second.amount === 20000 &&
      parsed.netAmount === -25000,
    'happy path should parse the expected transaction records and net amount',
  );

  assertThrows(
    () => parseTransaction('DR0923000024,-45000,DG0723000255'),
    (error) => error instanceof TransactionParseError && /even number/.test(error.message),
    'odd number of values should throw TransactionParseError',
  );
}

test('dr092300002445000Dg0723000255Module happy path parses default input', () => {
  const parsed = dr092300002445000Dg0723000255Module();
  assert.strictEqual(parsed.records.length, 2);
  assert.deepStrictEqual(parsed.records[0], { id: 'DR0923000024', amount: -45000 });
  assert.deepStrictEqual(parsed.records[1], { id: 'DG0723000255', amount: 20000 });
  assert.strictEqual(parsed.netAmount, -25000);
});

test('dr092300002445000Dg0723000255Module failure path rejects odd value counts', () => {
  assert.throws(
    () => parseTransaction('DR0923000024,-45000,DG0723000255'),
    (error: unknown) =>
      error instanceof TransactionParseError && /even number/.test(error.message),
  );
});

runSelfTests();