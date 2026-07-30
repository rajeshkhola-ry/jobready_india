const fs = require('fs');
const vm = require('vm');
const code = fs.readFileSync('compression_server.js', 'utf8');
try {
  new vm.Script(code, { filename: 'compression_server.js' });
  console.log('OK');
} catch (e) {
  console.error(e.stack);
  process.exit(1);
}
