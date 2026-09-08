/**
 * Payment allocation module for:
 *
 *   DG1923000122,40000,DG0623000082,117.82
 *
 * CSV format:
 *   sourceDocument,sourceAmount,targetDocument,targetAmount
 */

export interface PaymentAllocation {
  readonly sourceDocument: string;
  readonly sourceAmount: number;
  readonly targetDocument: string;
  readonly targetAmount: number;
}

export const DEFAULT_PAYMENT_ALLOCATION: Readonly<PaymentAllocation> = Object.freeze({
  sourceDocument: 'DG1923000122',
  sourceAmount: 40000,
  targetDocument: 'DG0623000082',
  targetAmount: 117.82,
});

export class PaymentAllocationValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'PaymentAllocationValidationError';
  }
}

const CURRENCY_SCALE = 100;

function isNonEmptyString(value: unknown): value is string {
  return typeof value === 'string' && value.trim().length > 0;
}

function isFiniteAmount(value: unknown): value is number {
  return typeof value === 'number' && Number.isFinite(value);
}

function roundCurrency(value: number): number {
  return Math.round(value * CURRENCY_SCALE) / CURRENCY_SCALE;
}

function assertAllocationEqual(
  actual: PaymentAllocation,
  expected: PaymentAllocation,
): void {
  if (
    actual.sourceDocument !== expected.sourceDocument ||
    actual.sourceAmount !== expected.sourceAmount ||
    actual.targetDocument !== expected.targetDocument ||
    actual.targetAmount !== expected.targetAmount
  ) {
    throw new Error(
      `Payment allocation mismatch.\nExpected: ${JSON.stringify(expected)}\nActual:   ${JSON.stringify(actual)}`,
    );
  }
}

export function validatePaymentAllocation(
  allocation: PaymentAllocation,
): void {
  if (!isNonEmptyString(allocation.sourceDocument)) {
    throw new PaymentAllocationValidationError(
      'sourceDocument must be a non-empty string.',
    );
  }

  if (!isFiniteAmount(allocation.sourceAmount)) {
    throw new PaymentAllocationValidationError(
      'sourceAmount must be a finite number.',
    );
  }

  if (allocation.sourceAmount <= 0) {
    throw new PaymentAllocationValidationError(
      'sourceAmount must be greater than zero.',
    );
  }

  if (!isNonEmptyString(allocation.targetDocument)) {
    throw new PaymentAllocationValidationError(
      'targetDocument must be a non-empty string.',
    );
  }

  if (!isFiniteAmount(allocation.targetAmount)) {
    throw new PaymentAllocationValidationError(
      'targetAmount must be a finite number.',
    );
  }

  if (allocation.targetAmount < 0) {
    throw new PaymentAllocationValidationError(
      'targetAmount must be greater than or equal to zero.',
    );
  }
}

export function parsePaymentAllocationCsv(
  csvLine: string,
): PaymentAllocation {
  if (typeof csvLine !== 'string' || csvLine.trim().length === 0) {
    throw new PaymentAllocationValidationError(
      'CSV line must be a non-empty string.',
    );
  }

  const parts = csvLine.split(',').map((part) => part.trim());

  if (parts.length !== 4) {
    throw new PaymentAllocationValidationError(
      `Expected 4 comma-separated values, received ${parts.length}.`,
    );
  }

  const [sourceDocument, sourceAmountRaw, targetDocument, targetAmountRaw] =
    parts;

  if (sourceAmountRaw.length === 0 || targetAmountRaw.length === 0) {
    throw new PaymentAllocationValidationError(
      'Amount fields must not be empty.',
    );
  }

  const sourceAmount = Number(sourceAmountRaw);
  const targetAmount = Number(targetAmountRaw);

  if (!Number.isFinite(sourceAmount) || !Number.isFinite(targetAmount)) {
    throw new PaymentAllocationValidationError(
      'sourceAmount and targetAmount must be valid finite numbers.',
    );
  }

  const allocation: PaymentAllocation = Object.freeze({
    sourceDocument,
    sourceAmount,
    targetDocument,
    targetAmount,
  });

  validatePaymentAllocation(allocation);

  return allocation;
}

export function calculateOutstandingAmount(
  allocation: PaymentAllocation,
): number {
  validatePaymentAllocation(allocation);

  return roundCurrency(allocation.sourceAmount - allocation.targetAmount);
}

export function isFullyAllocated(allocation: PaymentAllocation): boolean {
  return calculateOutstandingAmount(allocation) === 0;
}

export function serializePaymentAllocation(
  allocation: PaymentAllocation,
): string {
  validatePaymentAllocation(allocation);

  return [
    allocation.sourceDocument,
    allocation.sourceAmount,
    allocation.targetDocument,
    allocation.targetAmount,
  ].join(',');
}

export function testHappyPath(): void {
  const actual = parsePaymentAllocationCsv(
    'DG1923000122,40000,DG0623000082,117.82',
  );

  const expected: PaymentAllocation = {
    sourceDocument: 'DG1923000122',
    sourceAmount: 40000,
    targetDocument: 'DG0623000082',
    targetAmount: 117.82,
  };

  assertAllocationEqual(actual, expected);

  const outstandingAmount = calculateOutstandingAmount(actual);

  if (Math.abs(outstandingAmount - 39882.18) > 0.000001) {
    throw new Error('Happy path test failed: unexpected outstanding amount.');
  }
}

export function testFailurePath(): void {
  try {
    parsePaymentAllocationCsv('DG1923000122,40000,DG0623000082');
    throw new Error(
      'Failure path test failed: expected a validation error.',
    );
  } catch (error) {
    if (!(error instanceof PaymentAllocationValidationError)) {
      throw error;
    }
  }
}

interface UnitTestDefinition {
  readonly name: string;
  readonly run: () => void;
}

export function runUnitTests(): void {
  const tests: readonly UnitTestDefinition[] = [
    {
      name: 'happy path: parses CSV and calculates outstanding amount',
      run: testHappyPath,
    },
    {
      name: 'failure path: rejects malformed CSV',
      run: testFailurePath,
    },
  ];

  let passed = 0;

  for (const unitTest of tests) {
    try {
      unitTest.run();
      passed += 1;
      console.log(`PASS: ${unitTest.name}`);
    } catch (error) {
      console.error(`FAIL: ${unitTest.name}`);
      throw error;
    }
  }

  console.log(`Executed ${passed}/${tests.length} unit tests successfully.`);
}

// Self-executing test suite (TDD mandate).
runUnitTests();