import { readFileSync, readdirSync } from 'node:fs';
import { resolve, relative, dirname } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import luaparse from 'luaparse';

// This is a local feedback selector. Full check/Quality remains the merge gate.
const slash = value => value.replaceAll('\\', '/');
function files(dir) {
  return readdirSync(dir, { withFileTypes: true }).flatMap(entry => {
    const path = `${dir}/${entry.name}`;
    return entry.isDirectory() ? files(path) : [path];
  });
}
function luaImports(source) {
  const references = new Set(), known = new Set();
  let dynamic = false, ast;
  try {
    ast = luaparse.parse(Buffer.from(source).toString('latin1'), {
      luaVersion: '5.3', scope: true, comments: false, encodingMode: 'pseudo-latin1',
    });
  } catch {
    // Incomplete/new syntax must not silently remove a test's Lua dependencies.
    return { references, dynamic: true };
  }
  const global = (node, name) => node?.type === 'Identifier' && node.name === name && !node.isLocal;
  function visit(node) {
    if (!node || typeof node !== 'object') return;
    if (Array.isArray(node)) { node.forEach(visit); return; }
    if (['CallExpression', 'StringCallExpression'].includes(node.type)) {
      const args = node.arguments ?? [node.argument];
      const direct = global(node.base, 'require');
      const protectedCall = global(node.base, 'pcall') && global(args[0], 'require');
      const loader = direct ? node.base : protectedCall ? args[0] : null;
      const target = args[direct ? 0 : 1];
      if (loader && args.length === (direct ? 1 : 2) && target?.type === 'StringLiteral') {
        known.add(loader);
        if (/^abyss_\w+$/.test(target.value)) references.add(`src/lua/${target.value}.lua`);
      }
    }
    // Aliases, shadowed loaders and executable code strings cannot be resolved safely.
    if (node.type === 'Identifier' && ['require', 'load', 'loadstring'].includes(node.name) && !known.has(node)) dynamic = true;
    for (const [key, child] of Object.entries(node)) if (!['comments', 'globals'].includes(key)) visit(child);
  }
  visit(ast);
  return { references, dynamic };
}
export function selectTests(changed, sources) {
  const paths = Object.keys(sources), deps = new Map(), integration = new Set(), dynamicImports = new Set();
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
    if (path.endsWith('.lua')) {
      const imports = luaImports(source);
      for (const target of imports.references) if (target in sources) references.add(target);
      if (imports.dynamic) dynamicImports.add(path);
    } else {
      // Includes Lua embedded in JS fixture builders; runtime builders stay conservative below.
      for (const match of source.matchAll(/\b(?:require\s*\(?\s*|pcall\s*\(\s*require\s*,\s*)['"](abyss_\w+)['"]/g)) {
        const target = `src/lua/${match[1]}.lua`;
        if (target in sources) references.add(target);
      }
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
  const affected = new Set(changed), mapped = new Set(), selected = [];
  const luaChange = changed.some(p => p.startsWith('src/lua/'));
  for (const test of roots) {
    const dependencies = closure(test);
    for (const path of changed) if (dependencies.has(path)) mapped.add(path);
    // Dynamic Lua builders are conservatively included for every Lua change.
    // Literal dependency analysis must not silently omit generated test programs.
    const dynamicLua = luaChange && ([...dependencies].some(p => dynamicImports.has(p)) || (js.includes(test)
      ? [...dependencies].some(p => /runLua|readdirSync/.test(sources[p] ?? ''))
      : [...dependencies].some(p => /\b(?:dofile|loadfile)\s*\(\s*[^'"\s)]/.test(sources[p] ?? ''))));
    // Script-driven integration tests can discover sources/fixtures at runtime.
    // Keep these for every script change rather than guessing their dynamic IO.
    const dynamicScript = changed.some(p => p.startsWith('scripts/')) && js.includes(test)
      && [...dependencies].some(p => /readdirSync|\bimport\s*\(\s*[^'"\s)]/.test(sources[p] ?? ''));
    if ([...dependencies].some(p => affected.has(p)) || dynamicLua || dynamicScript) selected.push(test);
  }
  // Dynamic candidates supplement known coverage; their presence cannot prove
  // that an otherwise unmapped change is safe to leave out of the full check.
  const unmapped = changed.find(path => !mapped.has(path));
  if (unmapped) return fallback(`No statically mapped test for input: ${unmapped}`);
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
