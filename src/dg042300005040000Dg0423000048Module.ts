/**
 * Parses a transaction string of the form:
 *   <sourceAccount>,<sourceAmount>,<destinationAccount>,<destinationAmount>
 *
 * The default input for this module is:
 *   DG0423000050,40000,DG0423000048,40000
 */
export interface ParsedTransaction {
  sourceAccount: string;
  sourceAmount: number;
  destinationAccount: string;
  destinationAmount: number;
}

export class TransactionParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TransactionParseError';
  }
}

const EXPECTED_PART_COUNT = 4;

export function splitTransactionInput(input: string): string[] {
  const parts = input.split(',').map((part) => part.trim());

  if (parts.length !== EXPECTED_PART_COUNT) {
    throw new TransactionParseError(
      `Expected ${EXPECTED_PART_COUNT} comma-separated values, received ${parts.length}.`,
    );
  }

  return parts;
}

export function parseTransactionAmount(rawAmount: string, fieldName: string): number {
  if (!rawAmount) {
    throw new TransactionParseError(`${fieldName} is required.`);
  }

  const amount = Number(rawAmount);

  if (!Number.isFinite(amount) || amount <= 0) {
    throw new TransactionParseError(`${fieldName} must be a positive number.`);
  }

  return amount;
}

export function createTransaction(parts: string[]): ParsedTransaction {
  if (parts.length !== EXPECTED_PART_COUNT) {
    throw new TransactionParseError(
      `Expected ${EXPECTED_PART_COUNT} parts, received ${parts.length}.`,
    );
  }

  const [sourceAccount, sourceAmountRaw, destinationAccount, destinationAmountRaw] = parts;

  if (!sourceAccount || !destinationAccount) {
    throw new TransactionParseError('Source and destination accounts are required.');
  }

  const sourceAmount = parseTransactionAmount(sourceAmountRaw, 'sourceAmount');
  const destinationAmount = parseTransactionAmount(destinationAmountRaw, 'destinationAmount');

  if (sourceAmount !== destinationAmount) {
    throw new TransactionParseError('Source and destination amounts must match.');
  }

  return {
    sourceAccount,
    sourceAmount,
    destinationAccount,
    destinationAmount,
  };
}

export function parseTransactionInput(input: string): ParsedTransaction {
  return createTransaction(splitTransactionInput(input));
}

export const DEFAULT_TRANSACTION_INPUT = 'DG0423000050,40000,DG0423000048,40000';

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${String(expected)}, received ${String(actual)}.`);
  }
}

function assertThrows(operation: () => unknown, message: string): void {
  let didThrow = false;

  try {
    operation();
  } catch {
    didThrow = true;
  }

  if (!didThrow) {
    throw new Error(`${message}: expected an error to be thrown.`);
  }
}

export function testHappyPath(): void {
  const parsed = parseTransactionInput(DEFAULT_TRANSACTION_INPUT);

  assertEqual(parsed.sourceAccount, 'DG0423000050', 'Happy path source account');
  assertEqual(parsed.sourceAmount, 40000, 'Happy path source amount');
  assertEqual(parsed.destinationAccount, 'DG0423000048', 'Happy path destination account');
  assertEqual(parsed.destinationAmount, 40000, 'Happy path destination amount');
}

export function testFailurePath(): void {
  assertThrows(
    () => parseTransactionInput('DG0423000050,40000,DG0423000048'),
    'Missing field failure path',
  );

  assertThrows(
    () => parseTransactionInput('DG0423000050,40000,DG0423000048,50000'),
    'Mismatched amount failure path',
  );

  assertThrows(
    () => parseTransactionInput('DG0423000050,not-a-number,DG0423000048,40000'),
    'Non-numeric amount failure path',
  );
}

export function runUnitTests(): void {
  testHappyPath();
  testFailurePath();
  console.log('All unit tests passed.');
}

export default parseTransactionInput;

// Run the mandatory unit-test suite when the module is loaded.
runUnitTests();

export const TEST_SUITE_EXECUTED = true;