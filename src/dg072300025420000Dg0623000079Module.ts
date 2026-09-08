/**
 * Transaction module for input:
 * DG0723000254,20000,DG0623000079,857.23
 */

export const TRANSACTION_INPUT = 'DG0723000254,20000,DG0623000079,857.23';

export interface Transaction {
  readonly sourceAccount: string;
  readonly sourceAmount: number;
  readonly destinationAccount: string;
  readonly destinationAmount: number;
}

const EXPECTED_FIELD_COUNT = 4;

export function parseAccount(value: string): string {
  const account = value.trim();
  if (account === '') {
    throw new Error('Account identifier cannot be empty');
  }
  return account;
}

export function parseAmount(value: string): number {
  const trimmed = value.trim();
  if (trimmed === '') {
    throw new Error('Amount cannot be empty');
  }

  const amount = Number(trimmed);
  if (!Number.isFinite(amount)) {
    throw new Error(`Invalid amount: ${trimmed}`);
  }

  return amount;
}

export function parseTransaction(input: string): Transaction {
  const parts = input.split(',');

  if (parts.length !== EXPECTED_FIELD_COUNT) {
    throw new Error(
      `Expected ${EXPECTED_FIELD_COUNT} comma-separated fields but received ${parts.length}`,
    );
  }

  const [sourceAccount = '', sourceAmount = '', destinationAccount = '', destinationAmount = ''] = parts;

  return {
    sourceAccount: parseAccount(sourceAccount),
    sourceAmount: parseAmount(sourceAmount),
    destinationAccount: parseAccount(destinationAccount),
    destinationAmount: parseAmount(destinationAmount),
  };
}

export const DEFAULT_TRANSACTION: Transaction = parseTransaction(TRANSACTION_INPUT);

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(`${message}: expected ${String(expected)}, got ${String(actual)}`);
  }
}

export function testHappyPath(): void {
  const transaction = parseTransaction(TRANSACTION_INPUT);

  assertEqual(transaction.sourceAccount, 'DG0723000254', 'sourceAccount');
  assertEqual(transaction.sourceAmount, 20000, 'sourceAmount');
  assertEqual(transaction.destinationAccount, 'DG0623000079', 'destinationAccount');
  assertEqual(transaction.destinationAmount, 857.23, 'destinationAmount');
}

export function testFailurePath(): void {
  let caught = false;

  try {
    parseTransaction('not-a-valid-transaction');
  } catch (error) {
    caught = error instanceof Error && error.message.includes('Expected 4');
  }

  assertEqual(caught, true, 'Expected parseTransaction to reject malformed input');
}

export function runUnitTests(): void {
  testHappyPath();
  testFailurePath();
}

function executeTestSuite(): void {
  try {
    runUnitTests();
    console.log('Test suite executed successfully: 2 tests passed.');
  } catch (error) {
    console.error('Test suite execution failed.', error);
    throw error;
  }
}

executeTestSuite();
