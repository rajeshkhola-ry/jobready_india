export interface Transaction {
  readonly id: string;
  readonly amount: number;
}

export const DEFAULT_TRANSACTION_INPUT =
  'DG3323000188,10000,DG0623000077,1270.02';

export class TransactionParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TransactionParseError';
  }
}

const ID_PATTERN = /^[A-Z]{2}\d{10}$/;

function splitCsv(input: string): string[] {
  return input.split(',').map((part) => part.trim());
}

function parseAmount(rawAmount: string, id: string): number {
  if (rawAmount.length === 0) {
    throw new TransactionParseError(`Missing amount for id "${id}".`);
  }

  const amount = Number(rawAmount);
  if (!Number.isFinite(amount)) {
    throw new TransactionParseError(
      `Invalid amount "${rawAmount}" for id "${id}".`,
    );
  }

  return amount;
}

export function parseTransactions(input: string): Transaction[] {
  if (input.trim().length === 0) {
    throw new TransactionParseError('Transaction input must not be empty.');
  }

  const parts = splitCsv(input);
  if (parts.length % 2 !== 0) {
    throw new TransactionParseError(
      `Transaction input must contain id,amount pairs; got ${parts.length} field(s).`,
    );
  }

  const transactions: Transaction[] = [];
  for (let index = 0; index < parts.length; index += 2) {
    const id = parts[index];
    const rawAmount = parts[index + 1];

    if (id.length === 0) {
      throw new TransactionParseError(`Missing id at field ${index + 1}.`);
    }

    if (!ID_PATTERN.test(id)) {
      throw new TransactionParseError(
        `Invalid transaction id "${id}" at field ${index + 1}. Expected two uppercase letters followed by ten digits.`,
      );
    }

    transactions.push({
      id,
      amount: parseAmount(rawAmount, id),
    });
  }

  return transactions;
}

function assertStrictEqual<T>(actual: T, expected: T, message: string): void {
  if (!Object.is(actual, expected)) {
    throw new Error(
      `${message}: expected ${String(expected)}, received ${String(actual)}`,
    );
  }
}

function assertThrows(
  run: () => unknown,
  predicate: (error: unknown) => boolean,
  message: string,
): void {
  try {
    run();
  } catch (error) {
    if (!predicate(error)) {
      throw new Error(
        `${message}: received unexpected error: ${String(error)}`,
      );
    }
    return;
  }

  throw new Error(`${message}: expected function to throw`);
}

export function runSelfTests(): readonly string[] {
  const results: string[] = [];

  const parsed = parseTransactions(DEFAULT_TRANSACTION_INPUT);
  assertStrictEqual(
    parsed.length,
    2,
    'Happy path should parse two transactions',
  );

  const first = parsed[0];
  const second = parsed[1];
  if (!first || !second) {
    throw new Error('Happy path should return both transactions');
  }

  assertStrictEqual(first.id, 'DG3323000188', 'Happy path first id');
  assertStrictEqual(first.amount, 10000, 'Happy path first amount');
  assertStrictEqual(second.id, 'DG0623000077', 'Happy path second id');
  assertStrictEqual(second.amount, 1270.02, 'Happy path second amount');
  results.push('happy path: parses two id/amount pairs');

  assertThrows(
    () => parseTransactions('DG3323000188,not-a-number'),
    (error) => error instanceof TransactionParseError,
    'Failure path should throw TransactionParseError for an invalid amount',
  );
  results.push('failure path: invalid amount throws TransactionParseError');

  return results;
}

const selfTestResults = runSelfTests();
console.log(`Executed ${selfTestResults.length} self-tests successfully:`);
for (const result of selfTestResults) {
  console.log(`- ${result}`);
}