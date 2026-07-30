'use strict';

var attempts = {};

function now() {
  return Date.now();
}

function cleanup() {
  var cutoff = now() - 15 * 60 * 1000;
  Object.keys(attempts).forEach(function (key) {
    if (attempts[key].lastAttempt < cutoff) {
      delete attempts[key];
    }
  });
}

function isAllowed(key, limit, windowMs) {
  cleanup();
  var record = attempts[key] || { count: 0, lastAttempt: 0 };
  var windowStart = now() - windowMs;
  if (record.lastAttempt < windowStart) {
    record.count = 0;
  }

  record.count += 1;
  record.lastAttempt = now();
  attempts[key] = record;

  return record.count <= limit;
}

module.exports = {
  isAllowed: isAllowed
};
