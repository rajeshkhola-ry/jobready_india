export interface Dr0723000193900000Dg0623000084Record {
  readonly debitReference: string;
  readonly debitAmountMinor: number;
  readonly creditReference: string;
  readonly conversionRate: number;
}

export class Dr0723000193900000Dg0623000084ParseError extends Error {
  public constructor(message: string) {
    super(message);
    this.name = 'Dr0723000193900000Dg0623000084ParseError';
  }
}

function toFiniteNumber(raw: string, fieldName: string): number {
  const trimmed = raw.trim();

  if (!trimmed) {
    throw new Dr0723000193900000Dg0623000084ParseError(`${fieldName} is required`);
  }

  const value = Number(trimmed);

  if (!Number.isFinite(value)) {
    throw new Dr0723000193900000Dg0623000084ParseError(`${fieldName} must be a finite number`);
  }

  return value;
}

export function parseDr0723000193900000Dg0623000084Record(
  input: string,
): Dr0723000193900000Dg0623000084Record {
  if (typeof input !== 'string') {
    throw new Dr0723000193900000Dg0623000084ParseError('input must be a string');
  }

  const parts = input.split(',').map((part) => part.trim());

  if (parts.length !== 4) {
    throw new Dr0723000193900000Dg0623000084ParseError(
      `expected 4 comma-separated fields, received ${parts.length}`,
    );
  }

  const debitReference = parts[0] ?? '';
  const rawDebitAmount = parts[1] ?? '';
  const creditReference = parts[2] ?? '';
  const rawRate = parts[3] ?? '';

  if (!debitReference) {
    throw new Dr0723000193900000Dg0623000084ParseError('debitReference is required');
  }

  if (!creditReference) {
    throw new Dr0723000193900000Dg0623000084ParseError('creditReference is required');
  }

  const debitAmountMinor = toFiniteNumber(rawDebitAmount, 'debitAmount');
  const conversionRate = toFiniteNumber(rawRate, 'conversionRate');

  return Object.freeze({
    debitReference,
    debitAmountMinor,
    creditReference,
    conversionRate,
  });
}

export function testHappyPath(): void {
  const record = parseDr0723000193900000Dg0623000084Record(
    'DR0723000193,-900000,DG0623000084,256.64',
  );

  assertEqual(record.debitReference, 'DR0723000193', 'debitReference');
  assertEqual(record.debitAmountMinor, -900000, 'debitAmountMinor');
  assertEqual(record.creditReference, 'DG0623000084', 'creditReference');
  assertEqual(record.conversionRate, 256.64, 'conversionRate');
}

export function testFailurePath(): void {
  assertThrows(
    () => parseDr0723000193900000Dg0623000084Record('DR0723000193,-900000,DG0623000084'),
    Dr0723000193900000Dg0623000084ParseError,
    'expected 4 comma-separated fields, received 3',
  );

  assertThrows(
    () =>
      parseDr0723000193900000Dg0623000084Record(
        'DR0723000193,not-a-number,DG0623000084,256.64',
      ),
    Dr0723000193900000Dg0623000084ParseError,
    'debitAmount must be a finite number',
  );
}

export function runUnitTests(): void {
  testHappyPath();
  testFailurePath();
}

function assertEqual(actual: unknown, expected: unknown, label: string): void {
  if (actual !== expected) {
    throw new Error(`${label} mismatch: expected ${String(expected)}, received ${String(actual)}`);
  }
}

function assertThrows(
  operation: () => unknown,
  expectedError: new (message: string) => Error,
  expectedMessage?: string,
): void {
  const didNotThrow = Symbol('didNotThrow');
  let caught: unknown = didNotThrow;

  try {
    operation();
  } catch (error) {
    caught = error;
  }

  if (caught === didNotThrow) {
    throw new Error('expected operation to throw, but it did not');
  }

  if (!(caught instanceof expectedError)) {
    throw new Error(`expected error ${expectedError.name}, received ${String(caught)}`);
  }

  if (expectedMessage !== undefined && (caught as Error).message !== expectedMessage) {
    throw new Error(
      `error message mismatch: expected ${expectedMessage}, received ${(caught as Error).message}`,
    );
  }
}

runUnitTests();