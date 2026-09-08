import { test } from 'node:test';

/**
 * Transfer reconciliation module for
 * DG3323000189 -> DG0623000078 (source amount 10000, destination amount 935.15).
 *
 * The module parses a comma-separated instruction and returns a result object
 * rather than throwing from the top-level API, so callers can handle failures
 * explicitly.
 */

export interface TransferInstruction {
  readonly sourceAccountId: string;
  readonly sourceAmount: number;
  readonly destinationAccountId: string;
  readonly destinationAmount: number;
}

export interface TransferReconciliation extends TransferInstruction {
  readonly difference: number;
}

export type TransferReconciliationResult =
  | { readonly ok: true; readonly value: TransferReconciliation }
  | { readonly ok: false; readonly error: string };

export class TransferValidationError extends Error {
  public constructor(message: string) {
    super(message);
    this.name = 'TransferValidationError';
  }
}

const ACCOUNT_ID_PATTERN = /^DG\d{10}$/;
const EXPECTED_FIELD_COUNT = 4;

function parseAccountId(rawValue: string): string {
  const accountId = rawValue.trim();
  if (!ACCOUNT_ID_PATTERN.test(accountId)) {
    throw new TransferValidationError(`Invalid account identifier: ${rawValue}`);
  }
  return accountId;
}

function parsePositiveAmount(rawValue: string): number {
  const amount = Number(rawValue.trim());
  if (!Number.isFinite(amount) || amount <= 0) {
    throw new TransferValidationError(`Invalid positive amount: ${rawValue}`);
  }
  return amount;
}

export function parseTransferInstruction(input: string): TransferInstruction {
  const fields = input.split(',');
  if (fields.length !== EXPECTED_FIELD_COUNT) {
    throw new TransferValidationError(
      `Expected ${EXPECTED_FIELD_COUNT} comma-separated fields but received ${fields.length}`,
    );
  }

  return {
    sourceAccountId: parseAccountId(fields[0]),
    sourceAmount: parsePositiveAmount(fields[1]),
    destinationAccountId: parseAccountId(fields[2]),
    destinationAmount: parsePositiveAmount(fields[3]),
  };
}

export function reconcileTransfer(instruction: TransferInstruction): TransferReconciliation {
  return {
    ...instruction,
    difference: instruction.sourceAmount - instruction.destinationAmount,
  };
}

export function processTransferInstruction(input: string): TransferReconciliationResult {
  try {
    const instruction = parseTransferInstruction(input);
    const reconciled = reconcileTransfer(instruction);
    return { ok: true, value: reconciled };
  } catch (error) {
    if (error instanceof TransferValidationError) {
      return { ok: false, error: error.message };
    }
    const message = error instanceof Error ? error.message : 'Unknown error';
    return { ok: false, error: message };
  }
}

// Simple assertion helpers keep the module dependency-free while still
// providing runnable smoke tests for the happy and failure paths.
function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `${message}: expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`,
    );
  }
}

function assertCloseTo(actual: number, expected: number, message: string): void {
  if (Math.abs(actual - expected) >= 1e-9) {
    throw new Error(`${message}: expected ${expected}, received ${actual}`);
  }
}

export function testHappyPath(): void {
  const result = processTransferInstruction('DG3323000189,10000,DG0623000078,935.15');
  assertEqual(result.ok, true, 'happy path should succeed');
  if (!result.ok) {
    throw new Error(`happy path unexpectedly failed: ${result.error}`);
  }

  assertEqual(result.value.sourceAccountId, 'DG3323000189', 'source account');
  assertEqual(result.value.destinationAccountId, 'DG0623000078', 'destination account');
  assertCloseTo(result.value.sourceAmount, 10000, 'source amount');
  assertCloseTo(result.value.destinationAmount, 935.15, 'destination amount');
  assertCloseTo(result.value.difference, 9064.85, 'reconciliation difference');
}

export function testFailurePath(): void {
  const result = processTransferInstruction('DG3323000189,10000');
  assertEqual(result.ok, false, 'failure path should report failure');
  if (result.ok) {
    throw new Error('failure path unexpectedly succeeded');
  }

  assertEqual(
    result.error,
    'Expected 4 comma-separated fields but received 2',
    'failure path error message',
  );
}

export function runSelfTests(): void {
  testHappyPath();
  testFailurePath();
}

test('happy path reconciles DG3323000189 -> DG0623000078', () => {
  testHappyPath();
});

test('failure path reports missing fields', () => {
  testFailurePath();
});