"use client";

import { FormEvent, useEffect, useState } from "react";
import { ArrowLeft, Eye, EyeOff, Gauge, Save, ShieldCheck } from "lucide-react";
import Link from "next/link";

type Settings = {
  freeTrialEnabled: boolean;
  personalRateInr: number;
  businessRateInr: number;
};

export default function VoiceShopAdminPage() {
  const [adminKey, setAdminKey] = useState("");
  const [showKey, setShowKey] = useState(false);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [status, setStatus] = useState("Enter the Voice Shop control key to load settings.");
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const fragment = new URLSearchParams(window.location.hash.slice(1));
    const token = fragment.get("sso");
    if (!token) return;

    window.history.replaceState(null, "", window.location.pathname);
    void (async () => {
      const exchange = await fetch("/api/admin/sso", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ token }),
      });
      if (!exchange.ok) {
        const data = await exchange.json().catch(() => null);
        setStatus(data?.error || "Unable to verify your main admin session.");
        return;
      }

      setBusy(true);
      setStatus("GETREADYJOB admin verified. Loading Voice Shop controls...");
      const response = await fetch("/api/admin/voice-shop");
      const data = await response.json();
      setBusy(false);
      if (!response.ok) {
        setStatus(data.error || "Unable to load Voice Shop settings.");
        return;
      }
      setSettings(data.settings);
      setStatus("Secure admin gateway connected. Voice Shop controls loaded.");
    })();
  }, []);

  async function loadSettings(event: FormEvent) {
    event.preventDefault();
    setBusy(true);
    const response = await fetch("/api/admin/voice-shop", { headers: { "x-voice-shop-admin-key": adminKey } });
    const data = await response.json();
    setBusy(false);
    if (!response.ok) {
      setSettings(null);
      setStatus(data.error || "Unable to load Voice Shop settings.");
      return;
    }
    setSettings(data.settings);
    setStatus("Voice Shop controls loaded.");
  }

  async function saveSettings(event: FormEvent) {
    event.preventDefault();
    if (!settings) return;
    setBusy(true);
    const response = await fetch("/api/admin/voice-shop", {
      method: "PUT",
      headers: { "content-type": "application/json", "x-voice-shop-admin-key": adminKey },
      body: JSON.stringify(settings),
    });
    const data = await response.json();
    setBusy(false);
    if (!response.ok) {
      setStatus(data.error || "Unable to save Voice Shop controls.");
      return;
    }
    setSettings(data.settings);
    setStatus("Saved. Voice Shop pricing and trial availability are updated.");
  }

  return (
    <main className="admin-shell">
      <header className="admin-topbar">
        <div><span className="brand-mark"><Gauge size={20} /></span><div><small>Caddaddy operations</small><strong>Admin Dashboard</strong></div></div>
        <Link href="/" className="admin-back"><ArrowLeft size={17} /> Voice Shop</Link>
      </header>

      <section className="admin-content">
        <div className="admin-heading"><p className="eyebrow">Isolated commerce settings</p><h1>Voice Shop Admin Controls</h1><p>Manage only Voice Shop rates and trial availability. GetReadyJob plans and rate controls are not connected to this module.</p></div>

        <article className="admin-card">
          <div className="admin-card-head"><div className="rate-icon"><ShieldCheck /></div><div><h2>Voice Shop Admin Controls</h2><p>Changes write directly to the Voice Shop settings database.</p></div></div>

          {!settings ? (
            <form className="admin-key-form" onSubmit={loadSettings}>
              <label>Admin control key<div className="secret-input"><input type={showKey ? "text" : "password"} value={adminKey} onChange={(event) => setAdminKey(event.target.value)} required autoComplete="current-password" /><button type="button" onClick={() => setShowKey((visible) => !visible)} aria-label={showKey ? "Hide key" : "Show key"}>{showKey ? <EyeOff size={17} /> : <Eye size={17} />}</button></div></label>
              <button className="primary-button" disabled={busy}>{busy ? "Loading..." : "Load controls"}</button>
            </form>
          ) : (
            <form className="admin-settings-form" onSubmit={saveSettings}>
              <section className="admin-control-block">
                <div><h3>2-Minute Free Trial</h3><p>Turn off to disable claims and remove every trial promotion from Voice Shop.</p></div>
                <button className={`switch-control ${settings.freeTrialEnabled ? "on" : "off"}`} type="button" role="switch" aria-checked={settings.freeTrialEnabled} onClick={() => setSettings({ ...settings, freeTrialEnabled: !settings.freeTrialEnabled })}><span /><b>{settings.freeTrialEnabled ? "ON" : "OFF"}</b></button>
              </section>

              <section className="admin-control-block rates-block">
                <div><h3>Per-minute base rates</h3><p>INR values are stored as the pricing source. USD is recalculated from the monthly average rate.</p></div>
                <div className="admin-rate-fields">
                  <label>Personal rate (₹/min)<input type="number" min="0.01" max="100000" step="0.01" value={settings.personalRateInr} onChange={(event) => setSettings({ ...settings, personalRateInr: Number(event.target.value) })} required /></label>
                  <label>Business rate (₹/min)<input type="number" min="0.01" max="100000" step="0.01" value={settings.businessRateInr} onChange={(event) => setSettings({ ...settings, businessRateInr: Number(event.target.value) })} required /></label>
                </div>
              </section>

              <div className="admin-save-row"><button className="primary-button" disabled={busy}><Save size={17} /> {busy ? "Saving..." : "Save Voice Shop controls"}</button></div>
            </form>
          )}
          <p className="admin-status" role="status">{status}</p>
        </article>
      </section>
    </main>
  );
}
