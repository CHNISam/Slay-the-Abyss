// Only immutable, file-independent source projections may use this cache.
export function deepFreezeSourceProof(value) {
  if (value === null || typeof value !== 'object') return value;
  for (const child of Object.values(value)) deepFreezeSourceProof(child);
  return Object.freeze(value);
}

export function cachePureSourceProjection(targets, project, {maxEntriesPerPair = 64} = {}) {
  if (!Number.isSafeInteger(maxEntriesPerPair) || maxEntriesPerPair < 1)
    throw new RangeError('positive finite source projection cache bound required');
  const paths = new Map();
  for (const [target, {files}] of Object.entries(targets)) for (const path of Object.keys(files)) {
    if (!paths.has(path)) paths.set(path, new Map());
    paths.get(path).set(target, new Map());
  }
  return (path, source, target) => {
    const cache = typeof source === 'string' ? paths.get(path)?.get(target) : undefined;
    if (!cache) return project(path, source, target);
    if (cache.has(source)) return cache.get(source);
    // A thrown validation never enters the cache. Raw strings distinguish LF,
    // CRLF, partial and unknown sources before any projector normalization.
    const previous = project(path, source, target);
    if (cache.size >= maxEntriesPerPair) cache.delete(cache.keys().next().value);
    cache.set(source, previous);
    return previous;
  };
}
