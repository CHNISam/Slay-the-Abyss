// Exact outer replay for the hero-visual slice. Older witnesses keep their bytes.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createHash } from 'node:crypto';

const normalize = source => source.replaceAll('\r\n', '\n');
const hash = source => createHash('sha256').update(source).digest('hex');
const bytes = normalize(readFileSync(new URL('../fixtures/hero-visual-source-inverse.json', import.meta.url), 'utf8'));
assert.equal(hash(bytes), '3bcd94e59c181c835fe82ae2087c407f25e716e4a5773fda664bed7e00a7151c', 'complete hero-visual replay layer identity');
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
