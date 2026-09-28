import fs from 'node:fs';

const [, , inputPath, outputPath] = process.argv;

if (!inputPath || !outputPath) {
  console.error('Usage: node tools/json_array_to_jsonl.mjs <input.json> <output.jsonl>');
  process.exit(1);
}

const rows = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
if (!Array.isArray(rows)) {
  console.error(`Expected a JSON array in ${inputPath}`);
  process.exit(1);
}

const out = fs.createWriteStream(outputPath, { encoding: 'utf8' });
for (const row of rows) {
  out.write(JSON.stringify(row));
  out.write('\n');
}
out.end();
out.on('finish', () => {
  console.log(rows.length);
});
