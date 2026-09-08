export type StopErrorCode = 'ALREADY_STOPPED';

export interface StopError {
  code: StopErrorCode;
  message: string;
}

export type StopResult = { ok: true } | { ok: false; error: StopError };

export interface StopController {
  readonly isStopped: boolean;
  stop(): StopResult;
}

export function createStopController(): StopController {
  let stopped = false;

  return {
    get isStopped(): boolean {
      return stopped;
    },
    stop(): StopResult {
      if (stopped) {
        return {
          ok: false,
          error: {
            code: 'ALREADY_STOPPED',
            message: 'The module is already stopped.',
          },
        };
      }

      stopped = true;
      return { ok: true };
    },
  };
}

export default createStopController;

interface VitestLike {
  describe(name: string, fn: () => void): void;
  it(name: string, fn: () => void): void;
  expect(actual: unknown): {
    toBe(expected: unknown): void;
    toBeTruthy(): void;
    toEqual(expected: unknown): void;
    toThrow(expected?: string | RegExp): void;
  };
}

const maybeVitest = (import.meta as unknown as { vitest?: VitestLike }).vitest;

if (maybeVitest) {
  const { describe, it, expect } = maybeVitest;

  describe('createStopController', () => {
    it('stops a running controller on the happy path', () => {
      const controller = createStopController();

      const result = controller.stop();

      expect(result.ok).toBe(true);
      expect(controller.isStopped).toBe(true);
    });

    it('returns an ALREADY_STOPPED error when stop is called twice', () => {
      const controller = createStopController();
      controller.stop();

      const result = controller.stop();

      expect(result.ok).toBe(false);
      if (!result.ok) {
        expect(result.error.code).toBe('ALREADY_STOPPED');
      }
    });
  });
}