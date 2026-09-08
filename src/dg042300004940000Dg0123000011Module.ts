/**
 * Parses and validates a DG transfer record supplied as a comma-separated string.
 *
 * Expected format:
 * <sourceAccount>,<sourceAmount>,<targetAccount>,<targetAmount>
 *
 * Example:
 * DG0423000049,40000,DG0123000011,636.54999999999995
 */

export interface DgTransferRecord {
  readonly sourceAccount: string;
  readonly sourceAmount: number;
  readonly targetAccount: string;
  readonly targetAmount: number;
}

export class DgTransferParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DgTransferParseError';
  }
}

const ACCOUNT_REFERENCE_PATTERN = /^DG\d{10}$/;
const MAX_SAFE_INTEGER = 9007199254740991;

function throwParseError(message: string): never {
  throw new DgTransferParseError(message);
}

export function parseAccountReference(
  rawValue: string,
  fieldName: string,
): string {
  if (typeof rawValue !== 'string') {
    throwParseError(`${fieldName} must be a string.`);
  }

  const value = rawValue.trim();

  if (!ACCOUNT_REFERENCE_PATTERN.test(value)) {
    throwParseError(
      `${fieldName} must match "DG" followed by 10 digits. Received: ${JSON.stringify(
        rawValue,
      )}`,
    );
  }

  return value;
}

export function parseSourceAmount(rawValue: string): number {
  if (typeof rawValue !== 'string') {
    throwParseError('sourceAmount must be a string.');
  }

  const value = rawValue.trim();

  if (!/^\d+$/.test(value)) {
    throwParseError(
      `sourceAmount must be a positive integer. Received: ${JSON.stringify(
        rawValue,
      )}`,
    );
  }

  const parsed = Number(value);

  if (
    parsed <= 0 ||
    parsed !== Math.floor(parsed) ||
    parsed > MAX_SAFE_INTEGER
  ) {
    throwParseError(
      `sourceAmount must be a positive safe integer. Received: ${JSON.stringify(
        rawValue,
      )}`,
    );
  }

  return parsed;
}

export function parseTargetAmount(rawValue: string): number {
  if (typeof rawValue !== 'string') {
    throwParseError('targetAmount must be a string.');
  }

  const value = rawValue.trim();

  if (value === '') {
    throwParseError('targetAmount must not be empty.');
  }

  const parsed = Number(value);

  if (!isFinite(parsed) || parsed <= 0) {
    throwParseError(
      `targetAmount must be a positive finite number. Received: ${JSON.stringify(
        rawValue,
      )}`,
    );
  }

  return parsed;
}

export function parseDgTransferRecord(input: string): DgTransferRecord {
  if (typeof input !== 'string') {
    throwParseError('Transfer record input must be a string.');
  }

  const fields = input.split(',');

  if (fields.length !== 4) {
    throwParseError(
      `Transfer record input must contain exactly 4 comma-separated fields. Received ${fields.length} field(s).`,
    );
  }

  const [sourceAccount, sourceAmountValue, targetAccount, targetAmountValue] =
    fields;

  const sourceAccountParsed = parseAccountReference(
    sourceAccount,
    'sourceAccount',
  );
  const targetAccountParsed = parseAccountReference(
    targetAccount,
    'targetAccount',
  );
  const sourceAmount = parseSourceAmount(sourceAmountValue);
  const targetAmount = parseTargetAmount(targetAmountValue);

  return {
    sourceAccount: sourceAccountParsed,
    sourceAmount,
    targetAccount: targetAccountParsed,
    targetAmount,
  };
}

export function validateDgTransferRecord(record: DgTransferRecord): void {
  if (typeof record !== 'object' || record === null) {
    throwParseError('Transfer record must be an object.');
  }

  parseAccountReference(record.sourceAccount, 'sourceAccount');
  parseSourceAmount(String(record.sourceAmount));
  parseAccountReference(record.targetAccount, 'targetAccount');
  parseTargetAmount(String(record.targetAmount));
}

export function formatDgTransferRecord(record: DgTransferRecord): string {
  validateDgTransferRecord(record);

  return [
    record.sourceAccount,
    record.sourceAmount.toString(),
    record.targetAccount,
    record.targetAmount.toString(),
  ].join(',');
}

export const dg042300004940000Dg0123000011Module: DgTransferRecord =
  parseDgTransferRecord(
    'DG0423000049,40000,DG0123000011,636.54999999999995',
  );

function assertEqual<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `${message}. Expected ${JSON.stringify(expected)}, received ${JSON.stringify(
        actual,
      )}`,
    );
  }
}

export interface DgTransferModuleUnitTest {
  readonly name: string;
  readonly run: () => void;
}

export const dg042300004940000Dg0123000011ModuleUnitTests: DgTransferModuleUnitTest[] =
  [
    {
      name: 'happy path parses and formats the supplied transfer record',
      run: () => {
        const expected: DgTransferRecord = {
          sourceAccount: 'DG0423000049',
          sourceAmount: 40000,
          targetAccount: 'DG0123000011',
          targetAmount: 636.54999999999995,
        };

        const actual = parseDgTransferRecord(
          'DG0423000049,40000,DG0123000011,636.54999999999995',
        );

        assertEqual(
          actual.sourceAccount,
          expected.sourceAccount,
          'sourceAccount mismatch',
        );
        assertEqual(
          actual.sourceAmount,
          expected.sourceAmount,
          'sourceAmount mismatch',
        );
        assertEqual(
          actual.targetAccount,
          expected.targetAccount,
          'targetAccount mismatch',
        );
        assertEqual(
          actual.targetAmount,
          expected.targetAmount,
          'targetAmount mismatch',
        );
        assertEqual(
          formatDgTransferRecord(actual),
          'DG0423000049,40000,DG0123000011,636.54999999999995',
          'formatted record mismatch',
        );
      },
    },
    {
      name: 'failure path rejects an invalid account reference',
      run: () => {
        let thrown: unknown = null;

        try {
          parseDgTransferRecord(
            'DG0423000049,40000,INVALID,636.54999999999995',
          );
        } catch (error) {
          thrown = error;
        }

        if (!(thrown instanceof DgTransferParseError)) {
          throw new Error(
            'Expected DgTransferParseError for invalid target account reference.',
          );
        }
      },
    },
  ];

export function runDgTransferModuleUnitTests(): void {
  const unitTests = dg042300004940000Dg0123000011ModuleUnitTests;

  try {
    for (const unitTest of unitTests) {
      unitTest.run();
    }
  } catch (error) {
    console.error('[DgTransferModule] Automated unit tests failed.', error);
    throw error;
  }

  console.info(
    `[DgTransferModule] Automated unit tests executed successfully: ${unitTests.length}/${unitTests.length} passed.`,
  );
}

export default dg042300004940000Dg0123000011Module;

// Execute the module unit tests when this module is loaded (TDD mandate).
runDgTransferModuleUnitTests();