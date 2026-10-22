import test from 'node:test';
import assert from 'node:assert/strict';
import { settlementGraphSource } from '../scripts/settlement-graph.mjs';

function harness() {
  const handlers = {}, calls = [], variables = {};
  const source = settlementGraphSource({ id: 1234567, name: "Abyss ' settlement" });
  const graph = { onSignal(name, callback) { handlers[name] = callback; return this; } };
  const g = { server(spec) { assert.equal(spec.id, 1234567); assert.equal(spec.name, "Abyss ' settlement");
    Object.assign(variables, spec.variables); return graph; } };
  const f = { get: key => variables[key], set: (key, value) => { variables[key] = value; },
    getListOfPlayerEntitiesOnTheField: () => ['player1', 'player2'],
    setPlayerSettlementSuccessStatus: (player, status) => calls.push([player, status]),
    printString() {}, settleStage: () => calls.push('settleStage') };
  Function('g', 'SettlementStatus', source.replace(/^import .*\n/gm, ''))(g, { Victory: 'win', Defeat: 'lose' });
  return { handlers, calls, f };
}

for (const [signal, status, opposite] of [['ABYSS_WIN', 'win', 'ABYSS_LOSE'], ['ABYSS_LOSE', 'lose', 'ABYSS_WIN']]) {
  test(`server ${signal} marks all players before settling once and rejects the opposite duplicate`, () => {
    const { handlers, calls, f } = harness();
    handlers[signal]({}, f);
    assert.deepEqual(calls, [['player1', status], ['player2', status], 'settleStage']);
    handlers[signal]({}, f); handlers[opposite]({}, f);
    assert.equal(calls.length, 3);
  });
}
test('generator rejects missing/unsafe graph metadata and safely quotes actual names', () => {
  for (const id of [undefined, 0, -1, 1.5, '123', Number.MAX_SAFE_INTEGER + 1])
    assert.throws(() => settlementGraphSource({ id, name: 'stage' }));
  assert.throws(() => settlementGraphSource({ id: 1, name: '' }));
  assert.match(settlementGraphSource({ id: 2, name: 'stage\n"x' }), /name:"stage\\n\\"x"/);
});
