// A task-scoped MCP host. Launch at the game's integrity level; never elevates itself.
import { mkdirSync, existsSync, readFileSync, readdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { playtestInput } from './playtest-input.mjs';

if (!process.argv[2] || process.argv[2] === '--help') {
  console.log('node live-session.mjs <new-task-output-directory>\nRequests: queue/*.json {label,name,arguments}; stop: queue/STOP.\nExtra operations: focus-capture {windowId}; focus-input {windowId,...editor_input arguments} for editor/dialogs; playtest-input {runId,windowId,...editor_input arguments} for playtests.');
  process.exit(process.argv[2] ? 0 : 1);
}
const output = resolve(process.argv[2]), queue = join(output, 'queue');
if (existsSync(join(output, 'bridge-ready.json'))) throw Error('Use a new task directory; preserve the existing session and evidence.');
mkdirSync(queue, { recursive: true });
const toolRoot = process.env.MILIASTRA_MCP_ROOT || 'D:/MiliastraTools/genshin-miliastra-mcp';
const sdk = part => import(pathToFileURL(join(toolRoot, 'node_modules/@modelcontextprotocol/sdk/dist/esm/client', part)));
const { Client } = await sdk('index.js');
const { StdioClientTransport } = await sdk('stdio.js');
const client = new Client({ name: 'abyss-official-client-session', version: '1' });
const python = process.env.MILIASTRA_PYTHON || 'C:/Users/Administrator/AppData/Local/Programs/Python/Python312/python.exe';
await client.connect(new StdioClientTransport({ command: process.execPath, args: [join(toolRoot, 'src/server.mjs')],
  env: { ...process.env, MILIASTRA_WORKSPACE: output, MILIASTRA_ALLOW_LIVE_WRITE: '0',
    MILIASTRA_PYTHON: python, MILIASTRA_PLAYTEST_PYTHON: python } }));
const call = (name, args) => client.callTool({ name, arguments: args }, undefined, { timeout: 120000 });
const data = result => result.structuredContent ?? JSON.parse(result.content.find(item => item.type === 'text').text);
function saveResult(label, result) {
  for (const [i, item] of (result.content ?? []).entries()) if (item.type === 'image') {
    writeFileSync(join(output, `${label}-${i}.png`), Buffer.from(item.data, 'base64'));
    item.data = '[saved locally]';
  }
  return result;
}
try {
  for (const uri of ['miliastra://workflow', 'miliastra://platform-rules'])
    writeFileSync(join(output, `${uri.split('//')[1]}.json`), JSON.stringify(await client.readResource({ uri }), null, 2));
  writeFileSync(join(output, 'tool-schemas.json'), JSON.stringify(await client.listTools(), null, 2));
  writeFileSync(join(output, 'bridge-ready.json'), JSON.stringify({ at: new Date().toISOString(), pid: process.pid, liveWriteEnabled: false }));
  while (!existsSync(join(queue, 'STOP'))) {
    for (const file of readdirSync(queue).filter(name => name.endsWith('.json') && !existsSync(join(queue, name + '.done'))).sort()) {
      let request, label = file.slice(0, -5);
      try {
        request = JSON.parse(readFileSync(join(queue, file), 'utf8').replace(/^\uFEFF/, ''));
        if (!/^[a-zA-Z0-9_-]+$/.test(request.label)) throw Error('Use a unique filename-safe label.');
        label = request.label;
        if (existsSync(join(output, `${label}.json`))) throw Error('Evidence label already exists.');
        let result;
        if (request.name === 'playtest-input') {
          result = await playtestInput(request.arguments ?? {}, { call, workspace: output,
            record: (stage, value) => writeFileSync(join(output, `${label}-${stage}.json`),
              JSON.stringify(saveResult(`${label}-${stage}`, value), null, 2)) });
        } else if (['focus-capture', 'focus-input'].includes(request.name)) {
          const { windowId, ...input } = request.arguments;
          const focused = await call('focus_editor_window', { windowId });
          saveResult(`${label}-focus`, focused);
          const capture = data(focused);
          if (focused.isError || !capture.captureId) throw Error(JSON.stringify(capture));
          result = await call(request.name === 'focus-input' ? 'editor_input' : 'capture_editor_window',
            request.name === 'focus-input' ? { ...input, captureId: capture.captureId } : { windowId, method: 'screen', maxWidth: 1600 });
        } else result = await call(request.name, request.arguments ?? {});
        writeFileSync(join(output, `${label}.json`), JSON.stringify({ at: new Date().toISOString(), request, result: saveResult(label, result) }, null, 2));
      } catch (error) {
        // Never replay a failed input: it may already have reached the game.
        writeFileSync(join(output, `${file}.error.json`), JSON.stringify({ request, error: String(error) }, null, 2));
      } finally { writeFileSync(join(queue, file + '.done'), new Date().toISOString()); }
    }
    await new Promise(resolve => setTimeout(resolve, 200));
  }
} finally { await client.close(); }
