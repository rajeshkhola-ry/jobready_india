"use client";

import { FormEvent, Suspense, useState } from "react";
import { ArrowRight, KeyRound } from "lucide-react";
import Link from "next/link";
import { useSearchParams } from "next/navigation";

export default function ResetPasswordPage() {
  return <Suspense fallback={<main className="reset-page">Loading...</main>}><ResetPasswordForm /></Suspense>;
}

function ResetPasswordForm() {
  const token = useSearchParams().get("token") || "";
  const [status, setStatus] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    const password = String(new FormData(event.currentTarget).get("password") || "");
    const response = await fetch("/api/auth/reset-password", {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ token, password }),
    });
    const data = await response.json();
    setStatus(data.message || data.error || "Unable to reset password.");
    setBusy(false);
  }

  return (
    <main className="reset-page">
      <section className="reset-panel">
        <div className="rate-icon"><KeyRound /></div>
        <p className="eyebrow">Caddaddy account security</p>
        <h1>Set a new password</h1>
        <p>Use at least eight characters, one uppercase letter, and one number.</p>
        <form className="auth-form" onSubmit={submit}>
          <label>New password<input name="password" type="password" minLength={8} required autoComplete="new-password" /></label>
          <button className="primary-button" disabled={busy}>{busy ? "Updating..." : "Update password"}<ArrowRight size={17} /></button>
        </form>
        {status && <p className="dialog-status">{status}</p>}
        <Link className="text-button" href="/">Return to Voice Shop</Link>
      </section>
    </main>
  );
}
