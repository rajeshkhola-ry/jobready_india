export interface DgRecord {
  readonly id: string;
  readonly amount: number;
}

export const DG_INPUT = 'DG0423000051,40000,DG0423000049,40000';

const DG_ID_PATTERN = /^DG\d{10}$/;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

export function validateRecord(record: DgRecord): void {
  if (record == null || typeof record.id !== 'string' || typeof record.amount !== 'number') {
    throw new Error('DG record must have a string id and a numeric amount.');
  }

  if (!DG_ID_PATTERN.test(record.id)) {
    throw new Error(
      `Invalid DG id "${record.id}". Expected format: DG followed by 10 digits.`,
    );
  }

  if (!Number.isSafeInteger(record.amount) || record.amount <= 0) {
    throw new Error(
      `Invalid amount "${record.amount}" for DG id "${record.id}". Amount must be a positive safe integer.`,
    );
  }
}

export function parseDgInput(input: string): DgRecord[] {
  if (typeof input !== 'string' || input.trim().length === 0) {
    throw new Error('DG input must be a non-empty string.');
  }

  const tokens = input.split(',').map((token) => token.trim());

  if (tokens.length === 0) {
    throw new Error('DG input must contain at least one token.');
  }

  if (tokens.length % 2 !== 0) {
    throw new Error(
      `DG input must contain id,amount pairs; got ${tokens.length} comma-separated token(s).`,
    );
  }

  if (tokens.some((token) => token.length === 0)) {
    throw new Error('DG input contains an empty token.');
  }

  const records: DgRecord[] = [];

  for (let index = 0; index < tokens.length; index += 2) {
    const id = tokens[index];
    const amountToken = tokens[index + 1];

    if (id === undefined || amountToken === undefined) {
      throw new Error(`DG input is missing a value at token index ${index}.`);
    }

    if (!DG_ID_PATTERN.test(id)) {
      throw new Error(`Invalid DG id "${id}". Expected format: DG followed by 10 digits.`);
    }

    const amount = Number(amountToken);

    if (!Number.isSafeInteger(amount) || amount <= 0) {
      throw new Error(
        `Invalid amount "${amountToken}" for DG id "${id}". Amount must be a positive safe integer.`,
      );
    }

    records.push({ id, amount });
  }

  return records;
}

export function sumAmounts(records: readonly DgRecord[]): number {
  let total = 0;

  for (const record of records) {
    validateRecord(record);
    total += record.amount;
  }

  return total;
}

export function getExpectedDgRecords(): DgRecord[] {
  return parseDgInput(DG_INPUT);
}

export function runUnitTests(): void {
  const tests: Array<{ name: string; fn: () => void }> = [
    {
      name: 'happy path: parses the expected DG input and sums the amounts',
      fn: () => {
        const records = parseDgInput(DG_INPUT);
        assert(records.length === 2, 'expected two records');

        const first = records[0]!;
        const second = records[1]!;

        assert(first.id === 'DG0423000051', 'first id mismatch');
        assert(first.amount === 40000, 'first amount mismatch');
        assert(second.id === 'DG0423000049', 'second id mismatch');
        assert(second.amount === 40000, 'second amount mismatch');
        assert(sumAmounts(records) === 80000, 'total amount mismatch');
      },
    },
    {
      name: 'failure path: rejects an odd number of tokens',
      fn: () => {
        let didThrow = false;

        try {
          parseDgInput('DG0423000051,40000,DG0423000049');
        } catch {
          didThrow = true;
        }

        assert(didThrow, 'expected parseDgInput to throw for odd token count');
      },
    },
  ];

  const failures: string[] = [];

  for (const test of tests) {
    try {
      test.fn();
    } catch (error) {
      failures.push(`${test.name}: ${error instanceof Error ? error.message : String(error)}`);
    }
  }

  if (failures.length > 0) {
    throw new Error(`Unit tests failed:\n${failures.join('\n')}`);
  }

  console.log(`Dg042300005140000Dg0423000049Module: ${tests.length} unit test(s) passed.`);
}

const Dg042300005140000Dg0423000049Module = {
  input: DG_INPUT,
  parse: parseDgInput,
  sum: sumAmounts,
  validateRecord,
  getExpectedDgRecords,
  runUnitTests,
};

runUnitTests();

export default Dg042300005140000Dg0423000049Module;