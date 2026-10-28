import { spawn } from 'node:child_process';

const outputLimit = 4 * 1024 * 1024;
// Raw fixtures have at least a 30s deadline. Hosted failures under overlap
// started at measured costs of 13.5s; retain 3x headroom for concurrent work.
export const serialThresholdMs = 10000;
export const luaSchedulingWeight = (weight, workers) => workers === 2 && weight >= serialThresholdMs ? weight * 2 : weight;

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
  const ordered = [...scripts].sort((a, b) => weight(b) - weight(a) || (a < b ? -1 : a > b ? 1 : 0));
  const exclusive = workers === 2 ? ordered.filter(script => weight(script) >= serialThresholdMs) : [];
  const queue = workers === 2 ? ordered.filter(script => weight(script) < serialThresholdMs) : ordered;
  const emit = onOutput ?? ((stdout, stderr) => { process.stdout.write(stdout); process.stderr.write(stderr); });
  const env = { ...process.env };
  delete env.NODE_TEST_CONTEXT;
  let next = 0, status = 0;

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
  async function executeSafely(script) {
    try { await execute(script); }
    catch (error) {
      status = 1;
      try { emit('', `Lua worker could not run ${script}: ${error.message}\n`); }
      catch { /* A failed output callback cannot prevent remaining fixtures. */ }
    }
  }
  // Finish each expensive fixture alone before starting the short-fixture pool.
  // Unknown fixtures use the conservative default and therefore run alone too.
  for (const script of exclusive) await executeSafely(script);
  async function consume() {
    while (next < queue.length) await executeSafely(queue[next++]);
  }
  await Promise.all(Array.from({ length: Math.min(workers, queue.length) }, consume));
  return status;
}
