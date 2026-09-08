/**
 * Settlement record parser module.
 *
 * Expected input shape:
 * sourceReference,amount,targetReference,fee
 *
 * Example: DR0723000192,-1000000,DG0623000083,935.15
 */

import assert from 'node:assert/strict';
import { test } from 'node:test';

export const DEFAULT_RECORD_FIELD_COUNT = 4;
export const SAMPLE_RECORD_INPUT = 'DR0723000192,-1000000,DG0623000083,935.15';

export interface SettlementRecord {
  readonly sourceReference: string;
  readonly amount: number;
  readonly targetReference: string;
  readonly fee: number;
}

export class SettlementRecordParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'SettlementRecordParseError';
    Object.setPrototypeOf(this, SettlementRecordParseError.prototype);
  }
}

export function splitRecord(input: string): string[] {
  if (typeof input !== 'string') {
    throw new SettlementRecordParseError('Input must be a string');
  }

  const trimmed = input.trim();
  if (trimmed.length === 0) {
    throw new SettlementRecordParseError('Input must not be empty');
  }

  return trimmed.split(',').map((field) => field.trim());
}

export function parseReference(value: string, fieldName: string): string {
  if (typeof value !== 'string') {
    throw new SettlementRecordParseError(`${fieldName} must be a string`);
  }

  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new SettlementRecordParseError(`${fieldName} must not be empty`);
  }

  return trimmed;
}

export function parseAmount(value: string, fieldName: string): number {
  if (typeof value !== 'string') {
    throw new SettlementRecordParseError(`${fieldName} must be a string`);
  }

  const trimmed = value.trim();
  if (trimmed.length === 0) {
    throw new SettlementRecordParseError(`${fieldName} must not be empty`);
  }

  const amount = Number(trimmed);
  if (!Number.isFinite(amount)) {
    throw new SettlementRecordParseError(`${fieldName} must be a valid finite number`);
  }

  return amount;
}

export function parseSettlementRecord(input: string): SettlementRecord {
  const parts = splitRecord(input);

  if (parts.length !== DEFAULT_RECORD_FIELD_COUNT) {
    throw new SettlementRecordParseError(
      `Expected ${DEFAULT_RECORD_FIELD_COUNT} fields, received ${parts.length}`,
    );
  }

  const [
    sourceReferenceText = '',
    amountText = '',
    targetReferenceText = '',
    feeText = '',
  ] = parts;

  return {
    sourceReference: parseReference(sourceReferenceText, 'sourceReference'),
    amount: parseAmount(amountText, 'amount'),
    targetReference: parseReference(targetReferenceText, 'targetReference'),
    fee: parseAmount(feeText, 'fee'),
  };
}

export interface SelfTestResult {
  readonly passed: boolean;
  readonly tests: ReadonlyArray<{
    readonly name: string;
    readonly passed: boolean;
    readonly error?: string;
  }>;
}

function assertCondition(condition: boolean, message: string): void {
  if (!condition) {
    throw new Error(message);
  }
}

function expectSettlementRecordParseError(action: () => void): void {
  try {
    action();
  } catch (error) {
    assertCondition(
      error instanceof SettlementRecordParseError,
      `expected SettlementRecordParseError, received ${String(error)}`,
    );
    return;
  }

  assertCondition(false, 'expected action to throw SettlementRecordParseError');
}

export function runSelfTests(): SelfTestResult {
  const tests: Array<{ name: string; passed: boolean; error?: string }> = [];

  const test = (name: string, fn: () => void): void => {
    try {
      fn();
      tests.push({ name, passed: true });
    } catch (error) {
      tests.push({
        name,
        passed: false,
        error: error instanceof Error ? error.message : String(error),
      });
    }
  };

  test('parses a valid settlement record', () => {
    const record = parseSettlementRecord(SAMPLE_RECORD_INPUT);

    assertCondition(
      record.sourceReference === 'DR0723000192',
      'sourceReference should match the input',
    );
    assertCondition(record.amount === -1000000, 'amount should match the input');
    assertCondition(
      record.targetReference === 'DG0623000083',
      'targetReference should match the input',
    );
    assertCondition(record.fee === 935.15, 'fee should match the input');
  });

  test('rejects a record with missing fields', () => {
    expectSettlementRecordParseError(() => {
      parseSettlementRecord('DR0723000192,-1000000');
    });
  });

  test('rejects a record with an invalid amount', () => {
    expectSettlementRecordParseError(() => {
      parseSettlementRecord('DR0723000192,not-a-number,DG0623000083,935.15');
    });
  });

  return {
    passed: tests.every((item) => item.passed),
    tests,
  };
}

test('parseSettlementRecord parses a valid settlement record', () => {
  const record = parseSettlementRecord(SAMPLE_RECORD_INPUT);

  assert.strictEqual(record.sourceReference, 'DR0723000192');
  assert.strictEqual(record.amount, -1000000);
  assert.strictEqual(record.targetReference, 'DG0623000083');
  assert.strictEqual(record.fee, 935.15);
});

test('parseSettlementRecord rejects a record with missing fields', () => {
  assert.throws(
    () => parseSettlementRecord('DR0723000192,-1000000'),
    SettlementRecordParseError,
  );
});

test('parseSettlementRecord rejects a record with an invalid amount', () => {
  assert.throws(
    () => parseSettlementRecord('DR0723000192,not-a-number,DG0623000083,935.15'),
    SettlementRecordParseError,
  );
});

const selfTestResult = runSelfTests();
if (!selfTestResult.passed) {
  const failures = selfTestResult.tests
    .filter((testItem) => !testItem.passed)
    .map((testItem) => `${testItem.name}: ${testItem.error ?? 'Unknown error'}`)
    .join('\n');
  throw new Error(`Settlement record self-tests failed:\n${failures}`);
}