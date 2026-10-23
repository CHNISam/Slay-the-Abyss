import { sha256 } from './native-candidate-audit.mjs';

// Use the installed compiler's existing decoder. Reject any non-lossless decode
// rather than dropping unknown protocol fields or guessing their meaning.
export function decodeGraphPayload(raw, type) {
  const message = type.decode(raw);
  return { rawSha256: sha256(raw), roundtrip: Buffer.from(type.encode(message).finish()).equals(raw),
    graph: type.toObject(message, { defaults: false, longs: String, enums: String, bytes: String }) };
}
function stable(value) {
  if (Object.is(value, -0)) return { signedZero: '-0' };
  if (typeof value === 'number' && !Number.isFinite(value)) return { nonFiniteNumber: String(value) };
  if (Array.isArray(value)) return value.map(stable);
  if (!value || typeof value !== 'object') return value;
  return Object.fromEntries(Object.keys(value).sort().map(key => [key, stable(value[key])]));
}
export function graphPayloadForComparison(graph) {
  const copy = structuredClone(graph);
  const removeCommentPosition = comment => { if (comment) { delete comment.x; delete comment.y; } };
  for (const node of copy.nodes ?? []) { delete node.x; delete node.y; removeCommentPosition(node.comments); }
  for (const comment of copy.comments ?? []) removeCommentPosition(comment);
  return stable(copy);
}
export function compareGraphPayloads(actual, expected) {
  const issues = [];
  if (!actual.roundtrip || !expected.roundtrip) issues.push({ code: 'GRAPH_SCHEMA_UNSUPPORTED',
    detail: 'decode/encode did not preserve original bytes; unknown fields or unsupported wire ordering cannot be certified' });
  const actualPayload = graphPayloadForComparison(actual.graph), expectedPayload = graphPayloadForComparison(expected.graph);
  const actualSha256 = sha256(JSON.stringify(actualPayload)), expectedSha256 = sha256(JSON.stringify(expectedPayload));
  if (actualSha256 !== expectedSha256) issues.push({ code: 'GRAPH_PAYLOAD_MISMATCH', detail: actual.graph.name });
  return { ok: issues.length === 0, graphId: actual.graph.id?.id, name: actual.graph.name,
    actualRawSha256: actual.rawSha256, expectedRawSha256: expected.rawSha256, actualSha256, expectedSha256,
    actualRoundtrip: actual.roundtrip, expectedRoundtrip: expected.roundtrip, issues,
    exclusions: ['GraphNode.x', 'GraphNode.y', 'GraphNode.comments.x/y', 'NodeGraph.comments[].x/y'],
    scope: 'All decoded NodeGraph fields and ordered arrays; no default hydration, field filtering or node renumbering beyond the listed layout coordinates.' };
}
