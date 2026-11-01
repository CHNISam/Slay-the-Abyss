import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { compareGraphPayloads } from '../scripts/native-graph-payload.mjs';

const fixture = JSON.parse(readFileSync(new URL('./fixtures/native-graph-payload/settlement.json', import.meta.url)));
function audit(change = () => {}) {
  const actual = structuredClone(fixture.record), expected = structuredClone(fixture.record);
  change(actual.graph, actual); return compareGraphPayloads(actual, expected);
}
test('actual complete decoded payload matches itself and only node layout coordinates are excluded', () => {
  assert.deepEqual(audit().issues, []);
  assert.deepEqual(audit(graph => { graph.nodes[0].x += 17; graph.nodes[0].y -= 23; }).issues, []);
});
test('literal, pin type, variable initial value and signal binding changes must fail', () => {
  const changes = [
    graph => { graph.nodes.flatMap(node => node.pins ?? []).find(pin => pin.value?.bConcreteValue?.value?.bEnum).value.bConcreteValue.value.bEnum.val = 0; },
    graph => { graph.nodes[0].pins[0].type += 1; },
    graph => { graph.graphValues[0].values.bEnum.val = 1; },
    graph => { graph.nodes[0].genericId.nodeId += 1; },
    graph => { graph.nodes[0].comments = { content: 'Changed comment' }; },
  ];
  for (const change of changes) assert.ok(audit(change).issues.some(issue => issue.code === 'GRAPH_PAYLOAD_MISMATCH'));
});
test('a graph which cannot roundtrip losslessly is unsupported, never certified', () => {
  const actual = { ...fixture.unsupportedProbe, graph: fixture.record.graph };
  assert.equal(actual.roundtrip, false);
  assert.notEqual(actual.rawSha256, fixture.record.rawSha256);
  assert.ok(compareGraphPayloads(actual, fixture.record).issues.some(issue => issue.code === 'GRAPH_SCHEMA_UNSUPPORTED'));
});

test('semantic float fields retain signed zero rather than collapsing through JSON', () => {
  const actual = structuredClone(fixture.record), expected = structuredClone(fixture.record);
  actual.graph.evaluationInterval = -0; expected.graph.evaluationInterval = 0;
  assert.ok(compareGraphPayloads(actual, expected).issues.some(issue => issue.code === 'GRAPH_PAYLOAD_MISMATCH'));
});
