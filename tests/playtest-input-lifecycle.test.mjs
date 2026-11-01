import test from 'node:test';
import assert from 'node:assert/strict';
import { resolve } from 'node:path';
import { playtestInput } from '../.codebuddy/skills/miliastra-wonderland/scripts/playtest-input.mjs';

const workspace = resolve('offline-playtest-session');
const runId = '52225f03-dd80-4aec-91e3-b7bef57e2412';
const request = { runId, windowId: '656322:35884', kind: 'click', x: 800, y: 740 };
const rpc = value => ({ structuredContent: value, content: [{ type: 'text', text: JSON.stringify(value) }] });
// Actual playtest_status field shape; neither elapsedSeconds nor duration authorizes input.
const playing = extra => ({ runId, runDir: resolve(workspace, 'playtests', runId), state: 'running',
  elapsedSeconds: 153, steps: [{ at: 61.4, step: 'playtest-requested' }, { at: 153.1, step: 'playing' }], ...extra });

function harness(statuses, { focus = rpc({ captureId: 'fresh-focus-capture' }), inputError } = {}) {
  const calls = [], evidence = [];
  const call = async (name, args) => {
    calls.push({ name, args });
    if (name === 'playtest_status') {
      const response = statuses.shift();
      if (response instanceof Error) throw response;
      assert.ok(response, 'unexpected extra status call');
      return response;
    }
    if (name === 'focus_editor_window') return focus;
    assert.equal(name, 'editor_input');
    if (inputError) throw inputError;
    return rpc({ inputSent: true });
  };
  return { calls, evidence, run: (args = request) => playtestInput(args, { call, workspace,
    record: (stage, result) => evidence.push({ stage, result }) }) };
}

test('playing input checks the actual run twice, uses the fresh focus capture and sends once', async () => {
  const h = harness([rpc(playing()), rpc(playing({ elapsedSeconds: 999999 }))]);
  assert.equal((await h.run({ ...request, captureId: 'stale-do-not-use' })).structuredContent.inputSent, true);
  assert.deepEqual(h.calls, [
    { name: 'playtest_status', args: { runId, waitSeconds: 0, includeScreenshots: false } },
    { name: 'focus_editor_window', args: { windowId: request.windowId } },
    { name: 'playtest_status', args: { runId, waitSeconds: 0, includeScreenshots: false } },
    { name: 'editor_input', args: { kind: 'click', x: 800, y: 740, captureId: 'fresh-focus-capture' } },
  ]);
  assert.deepEqual(h.evidence.map(item => item.stage), ['before-focus', 'focus', 'before-input']);
});

for (const state of ['succeeded', 'failed', 'starting', 'unknown', 'missing']) {
  test(`original ${state} run refuses without focus or input`, async () => {
    const h = harness([rpc(playing({ state }))]);
    await assert.rejects(h.run(), /not playing|already left/);
    assert.deepEqual(h.calls.map(call => call.name), ['playtest_status']);
  });
}

test('running but not yet playing refuses even with a large elapsed time', async () => {
  const h = harness([rpc(playing({ elapsedSeconds: 999999, steps: [{ step: 'playtest-requested', at: 1 }] }))]);
  await assert.rejects(h.run());
  assert.equal(h.calls.length, 1);
});

for (const step of ['left-playtest', 'log-collected']) {
  test(`running with ${step} evidence refuses before focus`, async () => {
    const h = harness([rpc(playing({ steps: [...playing().steps, { at: 296.4, step }] }))]);
    await assert.rejects(h.run());
    assert.equal(h.calls.length, 1);
  });
}

for (const ended of [playing({ state: 'succeeded' }), playing({ steps: [...playing().steps, { step: 'left-playtest' }] })]) {
  test(`run ending during focus (${ended.state}) sends zero inputs`, async () => {
    const h = harness([rpc(playing()), rpc(ended)]);
    await assert.rejects(h.run());
    assert.deepEqual(h.calls.map(call => call.name), ['playtest_status', 'focus_editor_window', 'playtest_status']);
  });
}

test('official result page still running permits its normal Leave input', async () => {
  const resultPage = playing({ levelEndedAt: 118, endedEarly: true });
  const h = harness([rpc(resultPage), rpc(resultPage)]);
  await h.run();
  assert.equal(h.calls.filter(call => call.name === 'editor_input').length, 1);
});

for (const failure of [new Error('status RPC disconnected'), { isError: true, ...rpc({ error: 'PLAYTEST_NOT_FOUND' }) },
  { content: [{ type: 'text', text: 'invalid JSON' }] }, rpc(null), rpc(playing({ error: 'runner failed' })),
  rpc(playing({ steps: null })), rpc(playing({ steps: [{ step: 'playing' }, null] }))]) {
  test('unavailable/error/malformed status refuses at either observation', async () => {
    for (const second of [false, true]) {
      const h = harness(second ? [rpc(playing()), failure] : [failure]);
      await assert.rejects(h.run());
      assert.equal(h.calls.filter(call => call.name === 'editor_input').length, 0);
      assert.equal(h.calls.filter(call => call.name === 'focus_editor_window').length, Number(second));
    }
  });
}

for (const extra of [{ runId: 'another-run' }, { runDir: resolve('other-session', 'playtests', runId) },
  { runDir: undefined }, { runId: undefined }, { runDir: `playtests/${runId}` }]) {
  test('wrong or missing actual run identity refuses at either observation', async () => {
    for (const second of [false, true]) {
      const wrong = rpc(playing(extra));
      const h = harness(second ? [rpc(playing()), wrong] : [wrong]);
      await assert.rejects(h.run(), /identity/);
      assert.equal(h.calls.filter(call => call.name === 'editor_input').length, 0);
    }
  });
}

test('text-only MCP status payload is accepted using the same checks', async () => {
  const textOnly = { content: [{ type: 'text', text: JSON.stringify(playing()) }] };
  const h = harness([textOnly, textOnly]);
  await h.run();
  assert.equal(h.calls.filter(call => call.name === 'editor_input').length, 1);
});

test('focus errors or missing capture refuse before any input', async () => {
  for (const focus of [{ isError: true, ...rpc({ error: 'WINDOW_NOT_FOUND' }) }, rpc({}), rpc({ captureId: 42 })]) {
    const h = harness([rpc(playing())], { focus });
    await assert.rejects(h.run());
    assert.deepEqual(h.calls.map(call => call.name), ['playtest_status', 'focus_editor_window']);
  }
});

test('input failure is not retried because it may have reached the game', async () => {
  const h = harness([rpc(playing()), rpc(playing())], { inputError: new Error('refresh failed after sending') });
  await assert.rejects(h.run(), /refresh failed/);
  assert.equal(h.calls.filter(call => call.name === 'editor_input').length, 1);
});

test('missing run/window and path-traversal run identities refuse before any RPC', async () => {
  for (const args of [{ ...request, runId: undefined }, { ...request, runId: '../other' }, { ...request, windowId: '' }]) {
    const h = harness([]);
    await assert.rejects(h.run(args));
    assert.equal(h.calls.length, 0);
  }
});
