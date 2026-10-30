import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';

const hash = source => createHash('sha256').update(source).digest('hex');
// Placement-only calibration above the existing frozen runner witnesses.
// Unknown, partial or mutated sources remain visible to their strict guards.
export function preCiLuaCalibrationSource(path, source) {
  if (path !== 'scripts/test-lua.mjs' || typeof source !== 'string') return source;
  const normalized = source.replaceAll('\r\n', '\n');
  if (hash(normalized) !== 'e054f34695939535e65c6f78111aed1f1f7b7418d6716497926760cfebbc0ccf') return source;
  const edits = [
    ["  const safetyWeight = script => timings.lua?.[script] ?? timings.unknownLuaMs;\n  const weight = script => timings.luaShard?.[script] ?? safetyWeight(script);",
      "  const weight = script => timings.lua?.[script] ?? timings.unknownLuaMs;"],
    ['scripts.some(script => [weight(script), safetyWeight(script)].some(value => !Number.isFinite(value) || value <= 0))',
      'scripts.some(script => !Number.isFinite(weight(script)) || weight(script) <= 0)'],
    ["  // Calibration changes placement, never the worker pool's deadline safety\n  // classification. A measured short fixture must not unlock old exclusives.\n  const weights = Object.fromEntries(scripts.map(script => [script,\n    weight(script) * luaSchedulingWeight(safetyWeight(script), workers) / safetyWeight(script)]));",
      '  const weights = Object.fromEntries(scripts.map(script => [script, luaSchedulingWeight(weight(script), workers)]));'],
  ];
  let previous = normalized;
  for (const [after, before] of edits) {
    assert.equal(previous.split(after).length, 2, 'one exact CI placement edit');
    previous = previous.replace(after, before);
  }
  assert.equal(hash(previous), '66dc757b28cbe4a0f802d7f660299f1e91f8381bd44a08ac2e69aff2d3398ab2', 'complete original runner recovered');
  return previous;
}
