import assert from "node:assert/strict";
import test from "node:test";
import { buildPriceCatalog, convertInrPrice, currencyForCountry } from "./pricing";

test("selects INR only for Indian customers", () => {
  assert.equal(currencyForCountry("IN"), "INR");
  assert.equal(currencyForCountry("US"), "USD");
  assert.equal(currencyForCountry(null), "USD");
});

test("rounds converted USD prices", () => {
  assert.equal(convertInrPrice(499, "USD", 83.2), 6);
  assert.equal(convertInrPrice(499, "INR", 83.2), 499);
});

test("builds both wallet and pass prices", () => {
  const catalog = buildPriceCatalog("INR", 84);
  assert.equal(catalog.walletRates.personal, 5);
  assert.equal(catalog.walletRates.business, 12.5);
  assert.equal(catalog.passes.length, 4);
  assert.equal(catalog.walletTopUps.length, 5);
});

test("keeps USD wallet rates distinct with two-decimal precision", () => {
  const catalog = buildPriceCatalog("USD", 84);
  assert.equal(catalog.walletRates.personal, 0.06);
  assert.equal(catalog.walletRates.business, 0.15);
});

test("uses admin-managed wallet rates", () => {
  const catalog = buildPriceCatalog("INR", 84, { personal: 7.25, business: 19.5 });
  assert.equal(catalog.walletRates.personal, 7.25);
  assert.equal(catalog.walletRates.business, 19.5);
});
