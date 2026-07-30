const fs=require('fs');
const vm=require('vm');
const code=fs.readFileSync('compression_server.js','utf8');
const lines=code.split(/\r?\n/);
for (let i=1;i<=lines.length;i++) {
  const snippet=lines.slice(0,i).join('\n');
  try {
    new vm.Script(snippet,{filename:'compression_server.js'});
  } catch (e) {
    console.log('failed at line', i);
    console.log(lines[i-1]);
    console.log(e.message);
    process.exit(0);
  }
}
console.log('no failure');
