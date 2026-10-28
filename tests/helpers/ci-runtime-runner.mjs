import { readFileSync } from 'node:fs';

const edits = JSON.parse(readFileSync(new URL('../fixtures/ci-runtime-runner-edits.json', import.meta.url), 'utf8'));

// Reverse only the exact reviewed scheduling import/function. Every byte of
// runLua, fixture deadlines and CLI failure handling remains protected by the
// original full-runner hash. Partial or unrelated edits cannot be normalized.
export function originalLuaRunner(source) {
  for (const { before, after } of edits) {
    if (source.split(after).length === 2) source = source.replace(after, before);
  }
  return source;
}
