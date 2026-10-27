import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { runLua } from '../scripts/test-lua.mjs';

test('all 12 original source-input groups retain their complete body and run once with the original 30-second budget', () => {
  const source = readFileSync('tests/lua/support/card_input_port_cases.lua', 'utf8').replaceAll('\r\n', '\n');
  const header = 'return function(first,last)\nfirst,last=assert(first),assert(last)\nlocal registered=0\n';
  const gating = '    registered=registered+1\n    if registered<first or registered>last then return end\n';
  const tail = "assert(registered==12 and passed==last-first+1,'source input partition coverage changed')\nend\n";
  assert.ok(source.startsWith(header));
  assert.ok(source.endsWith(tail));
  assert.equal(source.split(gating).length, 2);
  const original = source.slice(header.length, -tail.length).replace(gating, '');
  assert.equal(createHash('sha256').update(original).digest('hex'),
    '62b56bbabbe457f0c6480f576cc2f83d34d71e698d354d0a4644820f2a47fa14');
  const names = [...original.matchAll(/^test\('([^']+)', function\(\)/gm)].map(match => match[1]);
  assert.equal(names.length, 12);
  const seen = [];
  for (const [file, first, last] of [['card_input_port.lua', 1, 6], ['card_input_port_slice_2.lua', 7, 10],
    ['card_input_port_slice_3.lua', 11, 12]]) {
    assert.equal(readFileSync(`tests/lua/${file}`, 'utf8').trim(),
      `dofile('tests/lua/support/card_input_port_cases.lua')(${first},${last})`);
    const result = runLua(`tests/lua/${file}`, { timeout: 30000 });
    assert.equal(result.status, 0, result.stdout + result.stderr);
    const actual = [...result.stdout.matchAll(/^PASS source card input (.+)$/gm)].map(match => match[1]);
    assert.deepEqual(actual, names.slice(first - 1, last));
    seen.push(...actual);
  }
  assert.deepEqual(seen, names);
});
