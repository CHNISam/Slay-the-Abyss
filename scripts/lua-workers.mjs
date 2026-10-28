import { spawn } from 'node:child_process';

const outputLimit = 4 * 1024 * 1024;

export function canOverlapLuaFixture(script, measuredMs) {
  if (typeof script !== 'string' || !script.trim() || !Number.isFinite(measuredMs) || measuredMs <= 0) return false;
  const path = script.replaceAll('\\', '/');
  const longFixture = /(?:^|\/)tests\/lua\/(?:encounter_coverage|map_floor_boundaries|map_no_crossings|map_treasure_placement)\.lua$/.test(path);
  const uiFixture = /(?:^|\/)tests\/lua\/(?:battle_ui(?:_slice_[2-7])?|game_ui)\.lua$/.test(path);
  const originalBudget = longFixture ? 120000 : uiFixture ? 60000 : 30000;
  return measuredMs <= originalBudget / 3;
}

// Each wrapper retains the synchronous Lua runner's existing fixture deadline
// and output budget. Only independent wrapper processes overlap here.
export async function runLuaWorkers(scripts, { cli, workers = 2, weights = {}, cwd = process.cwd(), onOutput } = {}) {
  if (!Array.isArray(scripts) || !scripts.length || scripts.some(script => typeof script !== 'string' || !script.trim())
      || new Set(scripts).size !== scripts.length) throw new Error('Lua fixtures must be a nonempty array of unique nonempty paths');
  if (!Number.isInteger(workers) || workers < 1 || workers > 2) throw new Error('Lua workers must be an integer from 1 to 2');
  if (typeof cli !== 'string' || !cli.trim()) throw new Error('Lua wrapper CLI path is required');
  if (!weights || typeof weights !== 'object' || Array.isArray(weights)) throw new Error('Lua scheduling weights must be an object');
  if (typeof cwd !== 'string' || !cwd.trim()) throw new Error('Lua worker cwd must be a nonempty path');
  if (onOutput !== undefined && typeof onOutput !== 'function') throw new Error('Lua worker output callback must be a function');
  const weight = script => weights[script] ?? 10000;
  if (scripts.some(script => !Number.isFinite(weight(script)) || weight(script) <= 0)) throw new Error('Lua scheduling weights must be positive finite milliseconds');
  const queue = [...scripts].sort((a, b) => weight(b) - weight(a) || (a < b ? -1 : a > b ? 1 : 0));
  const emit = onOutput ?? ((stdout, stderr) => { process.stdout.write(stdout); process.stderr.write(stderr); });
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT;
  let status = 0;

  function execute(script) {
    return new Promise(resolve => {
      const chunks = { stdout: [], stderr: [] }, sizes = { stdout: 0, stderr: 0 };
      let failure;
      const child = spawn(process.execPath, [cli, script], { cwd, env, windowsHide: true });
      for (const stream of ['stdout', 'stderr']) child[stream].on('data', chunk => {
        if (sizes[stream] + chunk.length > outputLimit) {
          failure ??= `Lua worker output exceeded ${outputLimit} bytes (${script}, ${stream})`;
          child.kill();
          return;
        }
        sizes[stream] += chunk.length;
        chunks[stream].push(chunk);
      });
      child.on('error', error => { failure ??= `Lua worker could not run ${script}: ${error.message}`; });
      child.on('close', (code, signal) => {
        if (signal) failure ??= `Lua worker terminated by ${signal}: ${script}`;
        const stdout = Buffer.concat(chunks.stdout).toString('utf8');
        const stderr = Buffer.concat(chunks.stderr).toString('utf8') + (failure ? `\n${failure}\n` : '');
        if (failure || code !== 0) status = 1;
        try { emit(stdout, stderr); }
        catch (error) { status = 1; process.stderr.write(`Lua worker output callback failed: ${error.message}\n`); }
        resolve();
      });
    });
  }
  async function runQueue(queue, count) {
    let next = 0;
    async function consume() {
      while (next < queue.length) {
        const script = queue[next++];
        try { await execute(script); }
        catch (error) {
          status = 1;
          try { emit('', `Lua worker could not run ${script}: ${error.message}\n`); }
          catch { /* A failed output callback cannot prevent remaining fixtures. */ }
        }
      }
    }
    await Promise.all(Array.from({ length: Math.min(count, queue.length) }, consume));
  }
  if (workers === 1) await runQueue(queue, 1);
  else {
    // Keep all uncertain/near-budget work alone. Only measured fixtures with
    // threefold headroom can share a VM, after the serial phase has completed.
    const serial = [], parallel = [];
    for (const script of queue) (canOverlapLuaFixture(script, weights[script]) ? parallel : serial).push(script);
    await runQueue(serial, 1);
    await runQueue(parallel, workers);
  }
  return status;
}
