import { readFileSync, readdirSync } from 'node:fs';
import { resolve, relative, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';

// This is a local feedback selector. Full check/Quality remains the merge gate.
const slash = value => value.replaceAll('\\', '/');
function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const path = `${dir}/${entry.name}`;
    return entry.isDirectory() ? files(path) : [path];
  });
}
export function selectTests(changed, sources) {
  const paths = Object.keys(sources), deps = new Map(), integration = new Set();
  const js = paths.filter(p => /^tests\/[^/]+\.test\.mjs$/.test(p));
  const lua = paths.filter(p => /^tests\/lua\/[^/]+\.lua$/.test(p));
  const roots = [...js, ...lua];
  const fallback = reason => ({ full: true, reason, fast: [], integration: [], lua: [] });
  if (!changed.length) return fallback('No explicit change set; run the complete check');
  for (const path of changed) {
    if (!sources[path] || !/^(src\/lua\/.*\.lua|scripts\/.*\.mjs|tests\/.*\.(mjs|lua))$/.test(path))
      return fallback(`Unmodelled or deleted input: ${path}`);
    if (/scripts\/(test-affected|test-lua|build-.*)\.mjs$/.test(path))
      return fallback(`Shared build/test infrastructure: ${path}`);
  }
  for (const [path, source] of Object.entries(sources)) {
    const references = new Set();
    // Includes Lua embedded in JS fixture builders, as well as direct Lua imports.
    for (const match of source.matchAll(/\brequire\s*\(?\s*['"](abyss_[\w]+)['"]/g)) {
      const target = `src/lua/${match[1]}.lua`;
      if (target in sources) references.add(target);
    }
    for (const match of source.matchAll(/(?:from\s*|import\s*\(?\s*)['"](\.[^'"]+)['"]/g)) {
      const target = slash(relative(process.cwd(), resolve(dirname(path), match[1])));
      if (target in sources) references.add(target);
    }
    for (const match of source.matchAll(/['"](\.\.?\/[^'"\n]+\.(?:mjs|lua))['"]/g)) {
      const target = slash(relative(process.cwd(), resolve(dirname(path), match[1])));
      if (target in sources) references.add(target);
    }
    for (const match of source.matchAll(/['"]((?:tests|scripts|src)\/[^'"\n]+\.(?:mjs|lua))['"]/g)) {
      if (match[1] in sources) references.add(match[1]);
    }
    deps.set(path, references);
    if (/runLua|node:child_process|spawnSync|execFile|spawn\(/.test(source) || path.endsWith('.lua')) integration.add(path);
  }
  const closure = start => {
    const seen = new Set();
    function visit(path) { if (seen.has(path)) return; seen.add(path); for (const dep of deps.get(path) ?? []) visit(dep); }
    visit(start); return seen;
  };
  const affected = new Set(changed), selected = [];
  const luaChange = changed.some(p => p.startsWith('src/lua/'));
  for (const test of roots) {
    const dependencies = closure(test);
    // Dynamic Lua builders are conservatively included for every Lua change.
    // Literal dependency analysis must not silently omit generated test programs.
    const dynamicLua = luaChange && (js.includes(test)
      ? [...dependencies].some(p => /runLua|readdirSync/.test(sources[p] ?? ''))
      : [...dependencies].some(p => /\b(?:require|dofile|loadfile)\s*\(\s*[^'"\s)]/.test(sources[p] ?? '')));
    // Script-driven integration tests can discover sources/fixtures at runtime.
    // Keep these for every script change rather than guessing their dynamic IO.
    const dynamicScript = changed.some(p => p.startsWith('scripts/')) && js.includes(test)
      && [...dependencies].some(p => /readdirSync|\bimport\s*\(\s*[^'"\s)]/.test(sources[p] ?? ''));
    if ([...dependencies].some(p => affected.has(p)) || dynamicLua || dynamicScript) selected.push(test);
  }
  if (!selected.length) return fallback('No statically mapped test; use the complete check');
  const isIntegration = test => [...closure(test)].some(p => integration.has(p));
  return { full: false, reason: 'Transitive imports and literal fixture references',
    fast: selected.filter(p => js.includes(p) && !isIntegration(p)),
    integration: selected.filter(p => js.includes(p) && isIntegration(p)), lua: selected.filter(p => lua.includes(p)) };
}

function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit', windowsHide: true });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status ?? result.signal})`);
}
export function main(args) {
  const planOnly = args.includes('--plan'), tier = args.includes('--fast') ? 'fast' : 'related';
  const at = args.indexOf('--files');
  let changed;
  if (at >= 0) changed = args.slice(at + 1).filter(p => !p.startsWith('--')).map(slash);
  else {
    const base = args[args.indexOf('--base') + 1];
    if (!args.includes('--base') || !base) throw new Error('Provide --base <commit> or --files <paths...>; use --plan to inspect');
    const git = spawnSync('git', ['diff', '--name-only', base, '--'], { encoding: 'utf8' });
    if (git.status !== 0) throw new Error(git.stderr || 'Cannot resolve comparison base');
    changed = git.stdout.trim().split(/\r?\n/).filter(Boolean);
    const untracked = spawnSync('git', ['ls-files', '--others', '--exclude-standard'], { encoding: 'utf8' });
    if (untracked.status !== 0) throw new Error('Cannot inspect untracked inputs');
    changed.push(...untracked.stdout.trim().split(/\r?\n/).filter(Boolean));
  }
  const sources = Object.fromEntries(['src/lua', 'scripts', 'tests'].flatMap(files)
    .filter(p => /\.(lua|mjs)$/.test(p)).map(p => [p, readFileSync(p, 'utf8')]));
  const plan = selectTests([...new Set(changed)], sources);
  console.log(JSON.stringify({ tier, changed, ...plan }, null, 2));
  if (planOnly) return;
  const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const npmRun = name => process.platform === 'win32'
    ? run('cmd.exe', ['/d', '/s', '/c', `npm run ${name}`]) : run(npm, ['run', name]);
  if (plan.full) { npmRun('check'); return; }
  npmRun('build:data'); npmRun('build:ui');
  const tests = tier === 'fast' ? plan.fast : [...plan.fast, ...plan.integration];
  if (tests.length) run(process.execPath, ['--test', '--test-concurrency=1', ...tests]);
  if (tier !== 'fast') for (const fixture of plan.lua) run(process.execPath, ['scripts/test-lua.mjs', fixture]);
  console.log(`Completed ${tests.length} JS and ${tier === 'fast' ? 0 : plan.lua.length} Lua files; full Quality remains required.`);
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { main(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
