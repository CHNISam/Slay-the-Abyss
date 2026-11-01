import { isAbsolute, resolve } from 'node:path';

function payload(result) {
  if (result?.isError) throw Error('Playtest input refused: MCP returned an error.');
  const value = result?.structuredContent ?? JSON.parse(result?.content?.find(item => item.type === 'text')?.text);
  if (!value || typeof value !== 'object' || Array.isArray(value))
    throw Error('Playtest input refused: invalid MCP payload.');
  return value;
}

const samePath = (left, right) => process.platform === 'win32'
  ? resolve(left).toLowerCase() === resolve(right).toLowerCase()
  : resolve(left) === resolve(right);

// Two observations reduce stale inputs; they are not an atomic lock across MCP RPCs.
export async function playtestInput({ runId, windowId, ...input }, { call, workspace, record = () => {} }) {
  if (typeof runId !== 'string' || !/^[A-Za-z0-9_-]+$/.test(runId) ||
      typeof windowId !== 'string' || !windowId.trim() || typeof workspace !== 'string' || !isAbsolute(workspace))
    throw Error('Playtest input requires a runId, windowId and absolute session workspace.');
  const expectedRunDir = resolve(workspace, 'playtests', runId);
  async function check(stage) {
    const result = await call('playtest_status', { runId, waitSeconds: 0, includeScreenshots: false });
    await record(stage, result);
    const status = payload(result);
    if (status.runId !== runId || typeof status.runDir !== 'string' || !isAbsolute(status.runDir) ||
        !samePath(status.runDir, expectedRunDir))
      throw Error('Playtest input refused: status run identity does not match this session.');
    if (status.state !== 'running' || status.error || !Array.isArray(status.steps) ||
        status.steps.some(step => !step || typeof step.step !== 'string') ||
        !status.steps.some(step => step.step === 'playing') ||
        status.steps.some(step => ['left-playtest', 'log-collected'].includes(step.step)))
      throw Error('Playtest input refused: run is not playing or has already left.');
    // levelEndedAt alone means a result screen, which can still need a Leave click.
  }
  await check('before-focus');
  const focused = await call('focus_editor_window', { windowId });
  await record('focus', focused);
  const capture = payload(focused);
  if (typeof capture.captureId !== 'string' || !capture.captureId)
    throw Error('Playtest input refused: focus did not return a captureId.');
  await check('before-input');
  return call('editor_input', { ...input, captureId: capture.captureId });
}
