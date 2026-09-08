/// <reference types="vitest/importMeta" />
/**
 * Parses comma-separated ledger entry pairs, such as:
 * "DG0423000053,40000,DG0423000051,40000".
 *
 * The input is expected to contain an even number of comma-separated items.
 * Each pair represents a ledger entry: an identifier followed by an amount.
 */

export const DEFAULT_DG_LEDGER_INPUT = 'DG0423000053,40000,DG0423000051,40000';

export interface DgLedgerEntry {
  readonly id: string;
  readonly amount: number;
}

export class DgLedgerParseError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'DgLedgerParseError';
    Object.setPrototypeOf(this, DgLedgerParseError.prototype);
  }
}

const PAIR_ITEM_COUNT = 2;

function parseDgAmount(rawAmount: string): number {
  const trimmedAmount = rawAmount.trim();

  if (trimmedAmount.length === 0) {
    throw new DgLedgerParseError('Ledger amount cannot be empty.');
  }

  const amount = Number(trimmedAmount);

  if (!Number.isFinite(amount)) {
    throw new DgLedgerParseError(`Invalid ledger amount: "${rawAmount}".`);
  }

  return amount;
}

function parseDgEntryPair(id: string, rawAmount: string): DgLedgerEntry {
  const trimmedId = id.trim();

  if (trimmedId.length === 0) {
    throw new DgLedgerParseError('Ledger identifier cannot be empty.');
  }

  return {
    id: trimmedId,
    amount: parseDgAmount(rawAmount),
  };
}

export function parseDgLedgerPairs(input: string): readonly DgLedgerEntry[] {
  const trimmedInput = input.trim();

  if (trimmedInput.length === 0) {
    throw new DgLedgerParseError('Ledger input cannot be empty.');
  }

  const parts = trimmedInput.split(',');

  if (parts.length === 0 || parts.length % PAIR_ITEM_COUNT !== 0) {
    throw new DgLedgerParseError(
      `Ledger input must contain comma-separated ID/amount pairs. Received ${parts.length} item(s).`,
    );
  }

  const entries: DgLedgerEntry[] = [];

  for (let index = 0; index < parts.length; index += PAIR_ITEM_COUNT) {
    entries.push(parseDgEntryPair(parts[index], parts[index + 1]));
  }

  return entries;
}

export function runDgLedgerModuleTests(): void {
  // Happy path: two valid pairs parse into the expected entries.
  const happyPathEntries = parseDgLedgerPairs(DEFAULT_DG_LEDGER_INPUT);

  if (happyPathEntries.length !== 2) {
    throw new Error('Expected two ledger entries on the happy path.');
  }

  const firstEntry = happyPathEntries[0];
  const secondEntry = happyPathEntries[1];

  if (!firstEntry || firstEntry.id !== 'DG0423000053' || firstEntry.amount !== 40000) {
    throw new Error('First ledger entry did not parse correctly.');
  }

  if (!secondEntry || secondEntry.id !== 'DG0423000051' || secondEntry.amount !== 40000) {
    throw new Error('Second ledger entry did not parse correctly.');
  }

  // Failure path: an odd number of items is rejected.
  let oddItemErrorCaught = false;

  try {
    parseDgLedgerPairs('DG0423000053,40000,DG0423000051');
  } catch (error) {
    oddItemErrorCaught = error instanceof DgLedgerParseError;
  }

  if (!oddItemErrorCaught) {
    throw new Error('Expected an odd number of items to throw DgLedgerParseError.');
  }

  // Failure path: a non-numeric amount is rejected.
  let invalidAmountErrorCaught = false;

  try {
    parseDgLedgerPairs('DG0423000053,not-a-number,DG0423000051,40000');
  } catch (error) {
    invalidAmountErrorCaught = error instanceof DgLedgerParseError;
  }

  if (!invalidAmountErrorCaught) {
    throw new Error('Expected a non-numeric amount to throw DgLedgerParseError.');
  }
}

runDgLedgerModuleTests();

if (import.meta.vitest) {
  const { describe, it, expect } = import.meta.vitest;

  describe('parseDgLedgerPairs', () => {
    it('parses the default ledger input into two entries', () => {
      expect(parseDgLedgerPairs(DEFAULT_DG_LEDGER_INPUT)).toEqual([
        { id: 'DG0423000053', amount: 40000 },
        { id: 'DG0423000051', amount: 40000 },
      ]);
    });

    it('throws DgLedgerParseError for an odd number of items', () => {
      expect(() =>
        parseDgLedgerPairs('DG0423000053,40000,DG0423000051'),
      ).toThrow(DgLedgerParseError);
    });

    it('throws DgLedgerParseError for a non-numeric amount', () => {
      expect(() =>
        parseDgLedgerPairs('DG0423000053,not-a-number,DG0423000051,40000'),
      ).toThrow(DgLedgerParseError);
    });
  });
}