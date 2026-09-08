export interface ParsedEntry {
  id: string;
  amount: number;
}

export const TASK_INPUT = 'DG2723000340,20000,DG0423000054,40000';

export class TaskParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'TaskParseError';
  }
}

export function parseId(rawId: string): string {
  const id = rawId.trim();
  if (id === '') {
    throw new TaskParseError('Entry id is required');
  }
  return id;
}

export function parseAmount(rawAmount: string): number {
  const amountText = rawAmount.trim();
  if (amountText === '') {
    throw new TaskParseError('Amount is required');
  }

  const amount = Number(amountText);
  if (!Number.isFinite(amount)) {
    throw new TaskParseError(`Amount must be a finite number: "${rawAmount}"`);
  }

  return amount;
}

export function parseEntry(rawId: string, rawAmount: string): ParsedEntry {
  return {
    id: parseId(rawId),
    amount: parseAmount(rawAmount),
  };
}

export function parseTask(input: string): ParsedEntry[] {
  if (input.trim() === '') {
    throw new TaskParseError('Task input is empty');
  }

  const parts = input.split(',').map((part) => part.trim());
  if (parts.length % 2 !== 0) {
    throw new TaskParseError(
      'Task input must contain an even number of comma-separated values (id, amount pairs)',
    );
  }

  const entries: ParsedEntry[] = [];
  for (let index = 0; index < parts.length; index += 2) {
    entries.push(parseEntry(parts[index], parts[index + 1]));
  }

  return entries;
}

export function sumAmounts(entries: readonly ParsedEntry[]): number {
  return entries.reduce((total, entry) => total + entry.amount, 0);
}

export function toBalanceMap(entries: readonly ParsedEntry[]): ReadonlyMap<string, number> {
  const balances = new Map<string, number>();

  for (const entry of entries) {
    if (balances.has(entry.id)) {
      throw new TaskParseError(`Duplicate id found: ${entry.id}`);
    }
    balances.set(entry.id, entry.amount);
  }

  return balances;
}

export class Dg272300034020000Dg0423000054Module {
  private readonly taskInput: string;

  constructor(taskInput: string = TASK_INPUT) {
    this.taskInput = taskInput;
  }

  parse(): ParsedEntry[] {
    return parseTask(this.taskInput);
  }

  total(): number {
    return sumAmounts(this.parse());
  }

  balances(): ReadonlyMap<string, number> {
    return toBalanceMap(this.parse());
  }
}

export default Dg272300034020000Dg0423000054Module;

function assertEquals<T>(actual: T, expected: T, message: string): void {
  if (actual !== expected) {
    throw new Error(
      `Test failed: ${message}. Expected: ${String(expected)}, received: ${String(actual)}`,
    );
  }
}

export function runUnitTests(): void {
  const happyPathEntries = parseTask(TASK_INPUT);
  assertEquals(happyPathEntries.length, 2, 'happy path should parse two entries');
  assertEquals(happyPathEntries[0].id, 'DG2723000340', 'first id should be parsed');
  assertEquals(happyPathEntries[0].amount, 20000, 'first amount should be parsed');
  assertEquals(happyPathEntries[1].id, 'DG0423000054', 'second id should be parsed');
  assertEquals(happyPathEntries[1].amount, 40000, 'second amount should be parsed');
  assertEquals(sumAmounts(happyPathEntries), 60000, 'sum of amounts should be 60000');

  let failureCaught = false;
  try {
    parseTask('DG2723000340,not-a-number');
  } catch (error) {
    failureCaught = error instanceof TaskParseError;
  }
  assertEquals(
    failureCaught,
    true,
    'failure path should throw TaskParseError for an invalid amount',
  );

  console.log('Unit test suite executed successfully: happy path and failure path passed.');
}

runUnitTests();
