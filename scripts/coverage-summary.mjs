// Prints the Vitest coverage summary as a Markdown table (for the GitHub job summary).
import { readFileSync, existsSync } from 'node:fs';

const file = 'coverage/coverage-summary.json';
if (!existsSync(file)) {
  console.log('No coverage report was produced.');
  process.exit(0);
}
const summary = JSON.parse(readFileSync(file, 'utf8'));
const root = process.cwd() + '/';
const pct = (m) => `${m.pct.toFixed(1)}%`;
const rows = Object.entries(summary)
  .filter(([name]) => name !== 'total')
  .map(([name, m]) => `| ${name.replace(root, '')} | ${pct(m.lines)} | ${pct(m.branches)} | ${pct(m.functions)} |`);

console.log('### Unit test coverage\n');
console.log('| File | Lines | Branches | Functions |');
console.log('| --- | ---: | ---: | ---: |');
console.log(`| **Total** | **${pct(summary.total.lines)}** | **${pct(summary.total.branches)}** | **${pct(summary.total.functions)}** |`);
console.log(rows.join('\n'));
