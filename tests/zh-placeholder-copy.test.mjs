// TASK-4.8: contest-facing card/relic/status copy must not carry English placeholders.
import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const load = (p) => JSON.parse(readFileSync(new URL(`../${p}`, import.meta.url), 'utf8'));
const english = /[A-Za-z]{2,}/;
// Template placeholders such as {effects.0.value} or {cost} are filled at runtime.
const visible = (s) => String(s).replace(/\{[^}]*\}/g, '');

function offenders(rows, fields) {
  const out = [];
  for (const row of rows) for (const f of fields) {
    const v = row[f];
    if (typeof v === 'string' && english.test(visible(v))) out.push(`${row.id}.${f}: ${v}`);
  }
  return out;
}

test('card names and texts are Chinese without English placeholders', () => {
  assert.deepEqual(offenders(load('data/cards.json').cards, ['name', 'text', 'upgradeText']), []);
});

test('traveler presentation card templates contain no English words', () => {
  const cards = load('data/presentation/traveler.zh-CN.json').cards;
  const rows = Object.entries(cards).map(([id, v]) => ({ id, ...v }));
  assert.deepEqual(offenders(rows, ['name', 'textTemplate', 'upgradeTextTemplate']), []);
});

test('relic names and descriptions contain no English placeholders', () => {
  assert.deepEqual(offenders(load('data/relics.json').relics, ['name', 'description']), []);
});

test('status names and descriptions contain no English placeholders', () => {
  assert.deepEqual(offenders(load('data/statuses.json').statuses, ['name', 'description']), []);
});
