import { test } from 'node:test';

export const DEFAULT_ALLOCATION_INPUT = 'DG2723000339,20000,DG0423000053,40000';

export interface DgAllocation {
  readonly code: string;
  readonly amount: number;
}

export class DgAllocationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DgAllocationError';
  }
}

export class InvalidAllocationInputError extends DgAllocationError {
  constructor(message: string) {
    super(message);
    this.name = 'InvalidAllocationInputError';
  }
}

export class UnknownDgCodeError extends DgAllocationError {
  constructor(message: string) {
    super(message);
    this.name = 'UnknownDgCodeError';
  }
}

const DG_CODE_PATTERN = /^DG\d{10}$/i;

function normalizeDgCode(input: string): string {
  const normalized = input.trim().toUpperCase();
  if (!DG_CODE_PATTERN.test(normalized)) {
    throw new InvalidAllocationInputError(
      `Invalid DG code "${input}". Expected format DG followed by 10 digits.`,
    );
  }
  return normalized;
}

export function parseAllocationInput(input: string): readonly DgAllocation[] {
  const trimmedInput = input.trim();
  if (trimmedInput.length === 0) {
    throw new InvalidAllocationInputError('Allocation input must not be empty.');
  }

  const parts = trimmedInput.split(',').map((part) => part.trim());

  if (parts.length % 2 !== 0) {
    throw new InvalidAllocationInputError(
      'Allocation input must contain code,amount pairs; expected an even number of comma-separated values.',
    );
  }

  const allocations: DgAllocation[] = [];
  for (let index = 0; index < parts.length; index += 2) {
    const code = normalizeDgCode(parts[index]);
    const rawAmount = parts[index + 1];
    const amount = Number(rawAmount);

    if (rawAmount.length === 0 || !Number.isInteger(amount) || amount <= 0) {
      throw new InvalidAllocationInputError(
        `Invalid amount "${rawAmount}" for DG code "${code}". Amount must be a positive integer.`,
      );
    }

    if (allocations.some((allocation) => allocation.code === code)) {
      throw new InvalidAllocationInputError(`Duplicate DG code "${code}" in allocation input.`);
    }

    allocations.push({ code, amount });
  }

  return allocations;
}

export function getDefaultAllocations(): readonly DgAllocation[] {
  return parseAllocationInput(DEFAULT_ALLOCATION_INPUT);
}

export function getAllocationByCode(
  code: string,
  allocations: readonly DgAllocation[] = getDefaultAllocations(),
): DgAllocation {
  const normalizedCode = code.trim().toUpperCase();
  const match = allocations.find((allocation) => allocation.code === normalizedCode);

  if (!match) {
    throw new UnknownDgCodeError(`No allocation found for DG code "${code}".`);
  }

  return match;
}

export function getAmountByCode(
  code: string,
  allocations: readonly DgAllocation[] = getDefaultAllocations(),
): number {
  return getAllocationByCode(code, allocations).amount;
}

export function hasAllocation(
  code: string,
  allocations: readonly DgAllocation[] = getDefaultAllocations(),
): boolean {
  const normalizedCode = code.trim().toUpperCase();
  return allocations.some((allocation) => allocation.code === normalizedCode);
}

export function calculateTotal(
  allocations: readonly DgAllocation[] = getDefaultAllocations(),
): number {
  return allocations.reduce((total, allocation) => total + allocation.amount, 0);
}

function assertStrictEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `${message} - expected ${JSON.stringify(expected)}, received ${JSON.stringify(actual)}`,
    );
  }
}

function assertThrows(action: () => void, expectedErrorType: Function, message: string): void {
  try {
    action();
  } catch (error) {
    if (error instanceof expectedErrorType) {
      return;
    }

    throw new Error(
      `${message} - expected ${expectedErrorType.name} to be thrown, received ${
        error instanceof Error ? error.name : String(error)
      }`,
    );
  }

  throw new Error(
    `${message} - expected ${expectedErrorType.name} to be thrown, but no error was thrown.`,
  );
}

export function runSelfTests(): void {
  test('DEFAULT_ALLOCATION_INPUT happy path', () => {
    assertStrictEqual(
      getAmountByCode('DG2723000339'),
      20000,
      'DG2723000339 should map to 20000',
    );
    assertStrictEqual(
      getAmountByCode('DG0423000053'),
      40000,
      'DG0423000053 should map to 40000',
    );
    assertStrictEqual(calculateTotal(), 60000, 'Default allocation total should be 60000');

    const parsed = parseAllocationInput(DEFAULT_ALLOCATION_INPUT);
    assertStrictEqual(parsed.length, 2, 'Default allocation should contain two entries');
  });

  test('unknown DG code failure path', () => {
    assertThrows(
      () => getAmountByCode('DG0000000000'),
      UnknownDgCodeError,
      'Unknown DG code should fail',
    );
  });

  test('malformed allocation input failure path', () => {
    assertThrows(
      () => parseAllocationInput('DG2723000339,20000,DG0423000053'),
      InvalidAllocationInputError,
      'Malformed allocation input should fail',
    );
  });
}

runSelfTests();

export const Dg272300033920000Dg0423000053Module = {
  DEFAULT_ALLOCATION_INPUT,
  getDefaultAllocations,
  getAllocationByCode,
  getAmountByCode,
  hasAllocation,
  calculateTotal,
  parseAllocationInput,
  runSelfTests,
} as const;

export default Dg272300033920000Dg0423000053Module;