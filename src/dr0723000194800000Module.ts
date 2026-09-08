export const DR_PREFIX = 'DR';

export interface DrReference {
  readonly prefix: typeof DR_PREFIX;
  readonly serialNumber: string;
  readonly amountMinorUnits: number;
}

export type DrReferenceErrorCode =
  | 'EMPTY_INPUT'
  | 'INVALID_PREFIX'
  | 'MISSING_COMMA'
  | 'EMPTY_SERIAL'
  | 'INVALID_SERIAL'
  | 'EMPTY_AMOUNT'
  | 'INVALID_AMOUNT';

export interface DrReferenceParseError {
  readonly code: DrReferenceErrorCode;
  readonly message: string;
}

export type ParseDrReferenceResult =
  | { readonly ok: true; readonly value: DrReference }
  | { readonly ok: false; readonly error: DrReferenceParseError };

function parseFailure(
  code: DrReferenceErrorCode,
  message: string,
): ParseDrReferenceResult {
  return {
    ok: false,
    error: {
      code,
      message,
    },
  };
}

/**
 * Parses a DR reference string with the format:
 *   DR<serialNumber>,<amountMinorUnits>
 *
 * Example:
 *   DR0723000194,800000
 */
export function parseDrReference(input: string): ParseDrReferenceResult {
  if (input.length === 0) {
    return parseFailure('EMPTY_INPUT', 'Input must not be empty.');
  }

  if (!input.startsWith(DR_PREFIX)) {
    return parseFailure(
      'INVALID_PREFIX',
      `Input must start with "${DR_PREFIX}".`,
    );
  }

  const body = input.slice(DR_PREFIX.length);
  const commaIndex = body.indexOf(',');

  if (commaIndex === -1) {
    return parseFailure(
      'MISSING_COMMA',
      'Input must contain a comma separating the serial number and amount.',
    );
  }

  const serialNumber = body.slice(0, commaIndex);
  const amountText = body.slice(commaIndex + 1);

  if (serialNumber.length === 0) {
    return parseFailure('EMPTY_SERIAL', 'Serial number must not be empty.');
  }

  if (!/^\d+$/.test(serialNumber)) {
    return parseFailure(
      'INVALID_SERIAL',
      'Serial number must contain only digits.',
    );
  }

  if (amountText.length === 0) {
    return parseFailure('EMPTY_AMOUNT', 'Amount must not be empty.');
  }

  if (!/^\d+$/.test(amountText)) {
    return parseFailure(
      'INVALID_AMOUNT',
      'Amount must contain only digits.',
    );
  }

  const amountMinorUnits = Number(amountText);

  if (!Number.isSafeInteger(amountMinorUnits)) {
    return parseFailure(
      'INVALID_AMOUNT',
      'Amount must be a safe integer.',
    );
  }

  return {
    ok: true,
    value: {
      prefix: DR_PREFIX,
      serialNumber,
      amountMinorUnits,
    },
  };
}

export type DrReferenceValidationErrorCode =
  | 'INVALID_PREFIX'
  | 'EMPTY_SERIAL'
  | 'INVALID_SERIAL'
  | 'INVALID_AMOUNT';

export interface DrReferenceValidationError {
  readonly code: DrReferenceValidationErrorCode;
  readonly message: string;
}

export type ValidateDrReferenceResult =
  | { readonly ok: true }
  | { readonly ok: false; readonly error: DrReferenceValidationError };

function validationFailure(
  code: DrReferenceValidationErrorCode,
  message: string,
): ValidateDrReferenceResult {
  return {
    ok: false,
    error: {
      code,
      message,
    },
  };
}

/**
 * Validates an already-constructed DrReference value.
 */
export function validateDrReference(
  value: DrReference,
): ValidateDrReferenceResult {
  if (value.prefix !== DR_PREFIX) {
    return validationFailure(
      'INVALID_PREFIX',
      `Prefix must be "${DR_PREFIX}".`,
    );
  }

  if (value.serialNumber.length === 0) {
    return validationFailure(
      'EMPTY_SERIAL',
      'Serial number must not be empty.',
    );
  }

  if (!/^\d+$/.test(value.serialNumber)) {
    return validationFailure(
      'INVALID_SERIAL',
      'Serial number must contain only digits.',
    );
  }

  if (
    !Number.isSafeInteger(value.amountMinorUnits) ||
    value.amountMinorUnits < 0
  ) {
    return validationFailure(
      'INVALID_AMOUNT',
      'Amount must be a non-negative safe integer.',
    );
  }

  return { ok: true };
}

export type FormatDrReferenceResult =
  | { readonly ok: true; readonly value: string }
  | { readonly ok: false; readonly error: DrReferenceValidationError };

/**
 * Formats a DrReference value without throwing.
 */
export function tryFormatDrReference(
  value: DrReference,
): FormatDrReferenceResult {
  const validation = validateDrReference(value);

  if (!validation.ok) {
    return validation;
  }

  return {
    ok: true,
    value: `${value.prefix}${value.serialNumber},${value.amountMinorUnits}`,
  };
}

/**
 * Formats a DrReference value.
 *
 * Throws when the value is invalid. Prefer {@link tryFormatDrReference}
 * when callers need to handle the error path explicitly.
 */
export function formatDrReference(value: DrReference): string {
  const result = tryFormatDrReference(value);

  if (!result.ok) {
    throw new Error(result.error.message);
  }

  return result.value;
}

/**
 * Self-contained unit tests covering the happy path and a failure path.
 * They are intentionally synchronous and dependency-free so they can be
 * invoked directly from any test runner.
 */
export function runSelfTests(): void {
  const tests: ReadonlyArray<{ readonly name: string; readonly run: () => void }> = [
    {
      name: 'parseDrReference happy path parses DR0723000194,800000',
      run: () => {
        const happyParse = parseDrReference('DR0723000194,800000');

        if (!happyParse.ok) {
          throw new Error(
            `Happy path parse failed: ${happyParse.error.message}`,
          );
        }

        if (
          happyParse.value.serialNumber !== '0723000194' ||
          happyParse.value.amountMinorUnits !== 800000
        ) {
          throw new Error('Happy path parse produced unexpected values.');
        }

        const happyFormat = tryFormatDrReference(happyParse.value);

        if (
          !happyFormat.ok ||
          happyFormat.value !== 'DR0723000194,800000'
        ) {
          throw new Error('Happy path format did not round-trip correctly.');
        }
      },
    },
    {
      name: 'parseDrReference failure path returns INVALID_PREFIX',
      run: () => {
        const failureParse = parseDrReference('0723000194,800000');

        if (failureParse.ok || failureParse.error.code !== 'INVALID_PREFIX') {
          throw new Error(
            'Failure path parse did not return the expected INVALID_PREFIX error.',
          );
        }
      },
    },
  ];

  for (const test of tests) {
    test.run();
  }

  console.log(
    `[dr0723000194800000Module] automated self-test suite passed (${tests.length} tests).`,
  );
}

export default {
  DR_PREFIX,
  parseDrReference,
  validateDrReference,
  tryFormatDrReference,
  formatDrReference,
  runSelfTests,
};

// Execute the self-test suite at module load so the automated test
// requirement is satisfied by an actual test run rather than a dormant
// helper.
runSelfTests();
