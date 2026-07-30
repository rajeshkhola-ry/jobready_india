'use strict';

var crypto = require('crypto');

function hashPassword(password) {
  var salt = crypto.randomBytes(16).toString('hex');
  var derived = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
  return '$pbkdf2$' + salt + '$' + derived;
}

function verifyPassword(password, storedHash) {
  if (!storedHash || typeof storedHash !== 'string' || !storedHash.startsWith('$pbkdf2$')) {
    return false;
  }

  var parts = storedHash.split('$');
  if (parts.length !== 4) {
    return false;
  }

  var salt = parts[2];
  var expected = parts[3];
  var derived = crypto.pbkdf2Sync(password, salt, 100000, 64, 'sha512').toString('hex');
  return derived === expected;
}

function createAdminToken(payload, secret) {
  var header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  var body = Buffer.from(JSON.stringify(payload)).toString('base64url');
  var signature = crypto.createHmac('sha256', secret).update(header + '.' + body).digest('base64url');
  return header + '.' + body + '.' + signature;
}

function verifyAdminToken(token, secret) {
  if (!token || typeof token !== 'string') {
    return null;
  }

  var parts = token.split('.');
  if (parts.length !== 3) {
    return null;
  }

  var expectedSignature = crypto.createHmac('sha256', secret).update(parts[0] + '.' + parts[1]).digest('base64url');
  if (expectedSignature !== parts[2]) {
    return null;
  }

  try {
    return JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
  } catch (err) {
    return null;
  }
}

module.exports = {
  hashPassword: hashPassword,
  verifyPassword: verifyPassword,
  createAdminToken: createAdminToken,
  verifyAdminToken: verifyAdminToken
};
