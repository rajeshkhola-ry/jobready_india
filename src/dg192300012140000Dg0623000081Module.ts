export class EntryListParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EntryListParseError';
  }
}

export type ParsedEntry = Readonly<{
  identifier: string;
  amount: number;
}>;

export type LedgerPair = Readonly<{
  source: ParsedEntry;
  destination: ParsedEntry;
}>;

export const DEFAULT_LEDGER_INPUT = 'DG1923000121,40000,DG0623000081,1637.37';

const AMOUNT_PATTERN = /^[+-]?(?:\d+(?:\.\d*)?|\.\d+)$/;

function assert(condition: unknown, message: string): asserts condition {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

function validateIdentifier(token: unknown, position: number): string {
  if (typeof token !== 'string') {
    throw new EntryListParseError(`Identifier must be a string at position ${position}`);
  }

  const trimmed = token.trim();
  if (trimmed.length === 0) {
    throw new EntryListParseError(`Identifier must not be empty at position ${position}`);
  }

  return trimmed;
}

function validateAmountNumber(value: unknown, position: number): number {
  if (typeof value !== 'number' || !Number.isFinite(value)) {
    throw new EntryListParseError(`Amount must be a finite number at position ${position}`);
  }

  return value;
}

function parseAmount(token: unknown, position: number): number {
  if (typeof token !== 'string') {
    throw new EntryListParseError(`Amount token must be a string at position ${position}`);
  }

  const trimmed = token.trim();
  if (!AMOUNT_PATTERN.test(trimmed)) {
    throw new EntryListParseError(`Invalid amount token at position ${position}: "${token}"`);
  }

  const value = Number(trimmed);
  if (!Number.isFinite(value)) {
    throw new EntryListParseError(`Amount must be finite at position ${position}: "${token}"`);
  }

  return value;
}

export function parseEntryList(input: string): ParsedEntry[] {
  if (typeof input !== 'string') {
    throw new EntryListParseError('Input must be a string');
  }

  const rawTokens = input.split(',');

  if (rawTokens.length < 2) {
    throw new EntryListParseError('Expected at least one identifier and one amount');
  }

  if (rawTokens.length % 2 !== 0) {
    throw new EntryListParseError('Expected an even number of comma-separated tokens (identifier, amount pairs)');
  }

  const entries: ParsedEntry[] = [];

  for (let index = 0; index < rawTokens.length; index += 2) {
    const identifier = validateIdentifier(rawTokens[index], index + 1);
    const amount = parseAmount(rawTokens[index + 1], index + 2);
    entries.push({ identifier, amount });
  }

  return entries;
}

export function parseLedgerPair(input: string): LedgerPair {
  const entries = parseEntryList(input);

  if (entries.length !== 2) {
    throw new EntryListParseError('Expected exactly two ledger entries');
  }

  const source = entries[0];
  const destination = entries[1];

  if (!source || !destination) {
    throw new EntryListParseError('Expected exactly two ledger entries');
  }

  return { source, destination };
}

export function parseDefaultLedgerPair(): LedgerPair {
  return parseLedgerPair(DEFAULT_LEDGER_INPUT);
}

export function createLedgerPair(
  sourceIdentifier: string,
  sourceAmount: number,
  destinationIdentifier: string,
  destinationAmount: number,
): LedgerPair {
  const source = {
    identifier: validateIdentifier(sourceIdentifier, 1),
    amount: validateAmountNumber(sourceAmount, 2),
  };

  const destination = {
    identifier: validateIdentifier(destinationIdentifier, 3),
    amount: validateAmountNumber(destinationAmount, 4),
  };

  return { source, destination };
}

export function formatEntryList(entries: readonly ParsedEntry[]): string {
  if (!Array.isArray(entries)) {
    throw new EntryListParseError('Entries must be an array');
  }

  if (entries.length === 0) {
    throw new EntryListParseError('Entries must not be empty');
  }

  return entries
    .map((entry, index) => {
      const identifier = validateIdentifier(entry.identifier, index * 2 + 1);
      const amount = validateAmountNumber(entry.amount, index * 2 + 2);
      return `${identifier},${amount}`;
    })
    .join(',');
}

export function testHappyPath(): void {
  const pair = parseDefaultLedgerPair();

  assert(pair.source.identifier === 'DG1923000121', 'source identifier should match');
  assert(pair.source.amount === 40000, 'source amount should match');
  assert(pair.destination.identifier === 'DG0623000081', 'destination identifier should match');
  assert(pair.destination.amount === 1637.37, 'destination amount should match');

  const reparsed = formatEntryList(parseEntryList(DEFAULT_LEDGER_INPUT));
  assert(reparsed === DEFAULT_LEDGER_INPUT, 'round-trip should preserve input');
}

export function testFailurePath(): void {
  let threw = false;

  try {
    parseLedgerPair('DG1923000121,40000,DG0623000081');
  } catch (error) {
    threw = error instanceof EntryListParseError;
  }

  assert(threw, 'parseLedgerPair should reject an odd token list');

  threw = false;

  try {
    parseEntryList('DG1923000121,not-a-number');
  } catch (error) {
    threw = error instanceof EntryListParseError;
  }

  assert(threw, 'parseEntryList should reject an invalid amount');
}

export function runSelfTests(): void {
  console.log('Running module self-tests...');
  testHappyPath();
  testFailurePath();
  console.log('All module self-tests passed.');
}

runSelfTests();