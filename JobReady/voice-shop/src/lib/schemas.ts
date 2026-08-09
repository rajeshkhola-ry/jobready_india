import { z } from "zod";

export const signupSchema = z.object({
  fullName: z.string().trim().min(2).max(100),
  email: z.string().trim().email().transform((value) => value.toLowerCase()),
  mobile: z.string().trim().min(7).max(20),
  country: z.string().trim().min(2).max(80),
  password: z.string().min(8).max(128).regex(/[A-Z]/, "Add an uppercase letter").regex(/[0-9]/, "Add a number"),
});

export const loginSchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase()),
  password: z.string().min(1).max(128),
});

export const emailSchema = z.object({
  email: z.string().trim().email().transform((value) => value.toLowerCase()),
});

export const resetPasswordSchema = z.object({
  token: z.string().min(32),
  password: signupSchema.shape.password,
});

export const voiceShopSettingsSchema = z.object({
  freeTrialEnabled: z.boolean(),
  personalRateInr: z.number().positive().max(100000),
  businessRateInr: z.number().positive().max(100000),
});
