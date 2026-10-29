// Exact outer replay for the hero-visual slice. Older witnesses keep their bytes.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const normalize = source => source.replaceAll('\r\n', '\n');
const hash = source => createHash('sha256').update(source).digest('hex');
const bytes = normalize(readFileSync(new URL('../fixtures/hero-visual-source-inverse.json', import.meta.url), 'utf8'));
assert.equal(hash(bytes), '0c217f39d9c5bab23006cc822529c653ede6d03a8377485083724f8e4f042986', 'complete hero-visual replay layer identity');
export const heroVisualProof = JSON.parse(bytes);
assert.equal(heroVisualProof.schemaVersion, 1);

export function preHeroVisualSource(path, source) {
  if (typeof source !== 'string') return source;
  const normalized = normalize(source);
  const binding = heroVisualProof.files[path];
  if (!binding || hash(normalized) !== binding.afterSha256) return normalized;
  assert.equal(hash(binding.before), binding.beforeSha256, 'complete pre-hero-visual source recovered: ' + path);
  return binding.before;
}
