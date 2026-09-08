export const TRANSACTION_PAYLOAD = 'DR0723000195,-900000,DG0723000253,13266';

export interface TransactionRecord {
  readonly firstAccount: string;
  readonly firstAmount: number;
  readonly secondAccount: string;
  readonly secondAmount: number;
}

export interface TransactionExecutionOutcome {
  readonly record: TransactionRecord;
  readonly netAmount: number;
}

export class TransactionParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TransactionParseError';
  }
}

export type Result<T, E extends Error = Error> =
  | { readonly ok: true; readonly value: T }
  | { readonly ok: false; readonly error: E };

export function parseTransactionPayload(payload: string): Result<TransactionRecord, TransactionParseError> {
  const trimmedPayload = payload.trim();

  if (trimmedPayload.length === 0) {
    return {
      ok: false,
      error: new TransactionParseError('Transaction payload must not be empty.'),
    };
  }

  const fields = trimmedPayload.split(',');

  if (fields.length !== 4) {
    return {
      ok: false,
      error: new TransactionParseError(`Expected 4 comma-separated fields, received ${fields.length}.`),
    };
  }

  const [firstAccount, firstAmountRaw, secondAccount, secondAmountRaw] = fields as [
    string,
    string,
    string,
    string,
  ];

  const normalizedFirstAccount = firstAccount.trim();
  const normalizedSecondAccount = secondAccount.trim();
  const normalizedFirstAmountRaw = firstAmountRaw.trim();
  const normalizedSecondAmountRaw = secondAmountRaw.trim();

  if (normalizedFirstAccount.length === 0 || normalizedSecondAccount.length === 0) {
    return {
      ok: false,
      error: new TransactionParseError('Account identifiers must not be empty.'),
    };
  }

  if (normalizedFirstAmountRaw.length === 0 || normalizedSecondAmountRaw.length === 0) {
    return {
      ok: false,
      error: new TransactionParseError('Transaction amounts must not be empty.'),
    };
  }

  const firstAmount = Number(normalizedFirstAmountRaw);
  const secondAmount = Number(normalizedSecondAmountRaw);

  if (!Number.isFinite(firstAmount)) {
    return {
      ok: false,
      error: new TransactionParseError(`First amount is not a finite number: "${firstAmountRaw}".`),
    };
  }

  if (!Number.isFinite(secondAmount)) {
    return {
      ok: false,
      error: new TransactionParseError(`Second amount is not a finite number: "${secondAmountRaw}".`),
    };
  }

  return {
    ok: true,
    value: Object.freeze({
      firstAccount: normalizedFirstAccount,
      firstAmount,
      secondAccount: normalizedSecondAccount,
      secondAmount,
    }),
  };
}

export function calculateNetAmount(record: TransactionRecord): number {
  return record.firstAmount + record.secondAmount;
}

export function executeTransaction(payload: string): Result<TransactionExecutionOutcome, TransactionParseError> {
  const parsed = parseTransactionPayload(payload);

  if (!parsed.ok) {
    return parsed;
  }

  return {
    ok: true,
    value: {
      record: parsed.value,
      netAmount: calculateNetAmount(parsed.value),
    },
  };
}

export interface TestRunResult {
  readonly passed: boolean;
  readonly failures: readonly string[];
}

export function runUnitTests(): TestRunResult {
  const failures: string[] = [];

  try {
    const happyPath = executeTransaction(TRANSACTION_PAYLOAD);

    if (!happyPath.ok) {
      failures.push(`Happy path failed: ${happyPath.error.message}`);
    } else {
      if (happyPath.value.record.firstAccount !== 'DR0723000195') {
        failures.push('Happy path first account mismatch.');
      }
      if (happyPath.value.record.firstAmount !== -900000) {
        failures.push('Happy path first amount mismatch.');
      }
      if (happyPath.value.record.secondAccount !== 'DG0723000253') {
        failures.push('Happy path second account mismatch.');
      }
      if (happyPath.value.record.secondAmount !== 13266) {
        failures.push('Happy path second amount mismatch.');
      }
      if (happyPath.value.netAmount !== -886734) {
        failures.push('Happy path net amount mismatch.');
      }
    }
  } catch (error) {
    failures.push(`Happy path threw: ${error instanceof Error ? error.message : String(error)}`);
  }

  try {
    const failurePath = executeTransaction('DR0723000195,not-a-number,DG0723000253,13266');

    if (failurePath.ok) {
      failures.push('Failure path unexpectedly succeeded.');
    } else if (!(failurePath.error instanceof TransactionParseError)) {
      failures.push('Failure path returned an unexpected error type.');
    }
  } catch (error) {
    failures.push(`Failure path threw: ${error instanceof Error ? error.message : String(error)}`);
  }

  return {
    passed: failures.length === 0,
    failures,
  };
}

const automatedTestRun = runUnitTests();

if (!automatedTestRun.passed) {
  throw new Error(`Automated unit tests failed:\n${automatedTestRun.failures.join('\n')}`);
}

console.log('Automated unit tests passed.');

export default {
  TRANSACTION_PAYLOAD,
  parseTransactionPayload,
  executeTransaction,
  calculateNetAmount,
  runUnitTests,
  TransactionParseError,
};