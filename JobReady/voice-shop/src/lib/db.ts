import fs from "node:fs";
import path from "node:path";
import { DatabaseSync } from "node:sqlite";

class VoiceShopDatabase {
  constructor(private readonly database: DatabaseSync) {}

  exec(sql: string) {
    return this.database.exec(sql);
  }

  prepare(sql: string) {
    return this.database.prepare(sql);
  }

  pragma(statement: string) {
    return this.database.exec(`PRAGMA ${statement}`);
  }

  transaction<T>(callback: () => T) {
    return () => {
      this.database.exec("BEGIN IMMEDIATE");
      try {
        const result = callback();
        this.database.exec("COMMIT");
        return result;
      } catch (error) {
        this.database.exec("ROLLBACK");
        throw error;
      }
    };
  }
}

const globalForDatabase = globalThis as unknown as { voiceShopDatabase?: VoiceShopDatabase };

function initializeDatabase() {
  const existing = globalForDatabase.voiceShopDatabase;
  if (existing) {
    return existing;
  }

  const databaseFilename = path.basename(process.env.DATABASE_PATH || "voice-shop.db");
  const databaseDirectory = process.env.DATABASE_DIR
    ? path.resolve(process.env.DATABASE_DIR)
    : path.join(process.cwd(), "data");
  const databasePath = path.join(databaseDirectory, databaseFilename);
  fs.mkdirSync(path.dirname(databasePath), { recursive: true });

  const database = new VoiceShopDatabase(new DatabaseSync(databasePath));
  database.pragma("journal_mode = WAL");
  database.pragma("foreign_keys = ON");
  database.exec(`
  CREATE TABLE IF NOT EXISTS users (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    full_name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE COLLATE NOCASE,
    mobile TEXT NOT NULL,
    country TEXT NOT NULL,
    password_hash TEXT,
    auth_provider TEXT NOT NULL DEFAULT 'password',
    provider_subject TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS password_reset_tokens (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    token_hash TEXT NOT NULL UNIQUE,
    expires_at TEXT NOT NULL,
    used_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS wallets (
    user_id INTEGER PRIMARY KEY,
    balance_paise INTEGER NOT NULL DEFAULT 0 CHECK(balance_paise >= 0),
    low_balance_threshold_paise INTEGER NOT NULL DEFAULT 5000,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS wallet_topup_orders (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    razorpay_order_id TEXT NOT NULL UNIQUE,
    razorpay_payment_id TEXT UNIQUE,
    amount_paise INTEGER NOT NULL CHECK(amount_paise > 0),
    currency TEXT NOT NULL DEFAULT 'INR',
    status TEXT NOT NULL DEFAULT 'created' CHECK(status IN ('created', 'paid')),
    credited_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE INDEX IF NOT EXISTS idx_wallet_topup_orders_user
  ON wallet_topup_orders(user_id, created_at DESC);

  CREATE TABLE IF NOT EXISTS wallet_topup_tax_records (
    order_id INTEGER PRIMARY KEY,
    tax_treatment TEXT NOT NULL CHECK(tax_treatment IN ('gst_inclusive_domestic', 'export_of_services')),
    tax_rate_bps INTEGER NOT NULL CHECK(tax_rate_bps IN (0, 1800)),
    total_minor INTEGER NOT NULL CHECK(total_minor > 0),
    base_minor INTEGER NOT NULL CHECK(base_minor > 0),
    gst_minor INTEGER NOT NULL CHECK(gst_minor >= 0),
    wallet_credit_paise INTEGER NOT NULL CHECK(wallet_credit_paise > 0),
    exchange_rate REAL,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (order_id) REFERENCES wallet_topup_orders(id) ON DELETE CASCADE,
    CHECK(total_minor = base_minor + gst_minor)
  );

  CREATE TABLE IF NOT EXISTS free_trial_claims (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL UNIQUE,
    minutes_granted INTEGER NOT NULL DEFAULT 2,
    seconds_used INTEGER NOT NULL DEFAULT 0,
    claimed_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS package_passes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER NOT NULL,
    pass_code TEXT NOT NULL,
    starts_at TEXT NOT NULL,
    expires_at TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'active',
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
  );

  CREATE TABLE IF NOT EXISTS platform_settings (
    setting_key TEXT PRIMARY KEY,
    setting_value TEXT NOT NULL,
    updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  CREATE TABLE IF NOT EXISTS admin_alerts (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    alert_type TEXT NOT NULL,
    message TEXT NOT NULL,
    acknowledged_at TEXT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP
  );

  INSERT OR IGNORE INTO platform_settings(setting_key, setting_value)
  VALUES ('free_trial_enabled', 'true');

  INSERT OR IGNORE INTO platform_settings(setting_key, setting_value)
  VALUES ('wallet_rate_personal_inr', '5');

  INSERT OR IGNORE INTO platform_settings(setting_key, setting_value)
  VALUES ('wallet_rate_business_inr', '12.5');
`);

  globalForDatabase.voiceShopDatabase = database;
  return database;
}

export const db = new Proxy({} as VoiceShopDatabase, {
  get(_target, property) {
    const database = initializeDatabase();
    const value = Reflect.get(database, property);
    return typeof value === "function" ? value.bind(database) : value;
  },
});
