export interface TransactionRecord {
  code: string;
  amount: number;
  type: 'DR' | 'DG';
}

/**
 * Parses a record code and amount string into a TransactionRecord.
 * Throws an Error if the code or amount is invalid.
 */
export function parseRecord(code: string, amountStr: string): TransactionRecord {
  if (!/^DR\d{10}$/.test(code) && !/^DG\d{10}$/.test(code)) {
    throw new Error(`Invalid record code format: ${code}`);
  }

  const amount = Number(amountStr);
  if (isNaN(amount)) {
    throw new Error(`Invalid amount value: ${amountStr}`);
  }

  const type = code.startsWith('DR') ? 'DR' : 'DG';
  return { code, amount, type };
}

/**
 * Calculates the net amount by summing a DR record and a DG record.
 * Throws an Error if record types are not DR and DG respectively.
 */
export function calculateNetAmount(
  debit: TransactionRecord,
  credit: TransactionRecord
): number {
  if (debit.type !== 'DR') {
    throw new Error(`Expected debit record type DR, got ${debit.type}`);
  }
  if (credit.type !== 'DG') {
    throw new Error(`Expected credit record type DG, got ${credit.type}`);
  }
  return debit.amount + credit.amount;
}

// Specific handlers for this module's codes
export function getModuleDebitRecord(): TransactionRecord {
  return parseRecord('DR0723000194', '-800000');
}

export function getModuleCreditRecord(): TransactionRecord {
  return parseRecord('DG0723000252', '12600');
}

/**
 * Processes the module-specific transaction and returns the net amount.
 */
export function processModuleTransaction(): number {
  const debit = getModuleDebitRecord();
  const credit = getModuleCreditRecord();
  return calculateNetAmount(debit, credit);
}

// Self-executing test suite: run the module's automated assertions outside Jest
// so the TDD suite is actually executed whenever this file is loaded.
(function runSelfTests(): void {
  const failures: string[] = [];

  try {
    const result = processModuleTransaction();
    if (result !== -787400) {
      failures.push(`happy path expected -787400, got ${result}`);
    }
  } catch (error) {
    failures.push(`happy path threw: ${(error as Error).message}`);
  }

  try {
    parseRecord('XX0723000194', '100');
    failures.push('invalid code format did not throw');
  } catch (error) {
    if (!/Invalid record code format/.test((error as Error).message)) {
      failures.push(`invalid code format threw wrong error: ${(error as Error).message}`);
    }
  }

  try {
    parseRecord('DR0723000194', 'notANumber');
    failures.push('invalid amount did not throw');
  } catch (error) {
    if (!/Invalid amount value/.test((error as Error).message)) {
      failures.push(`invalid amount threw wrong error: ${(error as Error).message}`);
    }
  }

  try {
    const fakeDebit = parseRecord('DG0723000252', '100');
    const fakeCredit = parseRecord('DR0723000194', '-100');
    calculateNetAmount(fakeDebit, fakeCredit);
    failures.push('reversed debit/credit types did not throw');
  } catch (error) {
    if (!/Expected debit record type DR/.test((error as Error).message)) {
      failures.push(`reversed debit/credit types threw wrong error: ${(error as Error).message}`);
    }
  }

  if (failures.length > 0) {
    throw new Error(`dr0723000194800000Dg0723000252Module self-test failed:\n${failures.join('\n')}`);
  }

  console.log('dr0723000194800000Dg0723000252Module automated test suite passed');
})();