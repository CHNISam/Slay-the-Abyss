import { appendFileSync, readFileSync, readdirSync } from 'node:fs';
import { resolve, relative, dirname, posix } from 'node:path';
import { spawnSync } from 'node:child_process';
import { pathToFileURL } from 'node:url';
import luaparse from 'luaparse';
import {frozenBattleHandFixtures} from '../tests/helpers/battle-life-frozen-hand.mjs';

// This is a local feedback selector. Full check/Quality remains the merge gate.
const slash = value => value.replaceAll('\\', '/');
// Importing runLua does not execute its conditional fixture setup. Keep these
// helper edges on their real Lua entries, as with the historical replay port.
const conditionalRunnerFixtures = new Map([
  ['tests/helpers/historical-presentation-runner.mjs', new Set(['tests/lua/presentation_responsibilities_trace.lua'])],
  ['tests/helpers/battle-life-frozen-hand.mjs', new Set(frozenBattleHandFixtures)],
]);
// These are virtual graph nodes, not files read from a possibly stale build/.
// Keep the producer identities aligned with build:data/build:ui's Lua outputs.
const generated = {
  abyss_data: 'scripts/build-lua-data.mjs',
  abyss_original_v4_data: 'scripts/build-original-v4.mjs',
  abyss_theme: 'scripts/build-ui-theme.mjs',
  abyss_map_layout: 'scripts/map-ui-layout.mjs',
  abyss_map_controls: 'scripts/map-ui-layout.mjs',
  abyss_narrative: 'scripts/build-ui.mjs',
  abyss_presentation: 'scripts/build-ui.mjs',
  abyss_ui_layout: 'scripts/build-ui.mjs',
  abyss_ui_templates: 'scripts/build-ui.mjs',
};
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
      const loaders = ['require', 'dofile', 'loadfile'];
      const direct = loaders.some(name => global(node.base, name));
      const protectedCall = global(node.base, 'pcall') && loaders.some(name => global(args[0], name));
      const loader = direct ? node.base : protectedCall ? args[0] : null;
      const target = args[direct ? 0 : 1];
      if (loader && args.length === (direct ? 1 : 2) && target?.type === 'StringLiteral') {
        known.add(loader);
        if (loader.name !== 'require') references.add(slash(target.value).replace(/^\.\//, ''));
        // runLua searches src/lua/?.lua for every module name, not only abyss_*.
        // Lua's searchpath translates module dots to directory separators.
        // Missing/unmodelled targets are marked dynamic by selectTests below.
        else references.add(`src/lua/${slash(target.value).replaceAll('.', '/')}.lua`);
      }
    }
    // Aliases, shadowed loaders and executable code strings cannot be resolved safely.
    if (node.type === 'Identifier' && ['require', 'dofile', 'loadfile', 'load', 'loadstring'].includes(node.name) && !known.has(node)) dynamic = true;
    for (const [key, child] of Object.entries(node)) if (!['comments', 'globals'].includes(key)) visit(child);
  }
  visit(ast);
  return { references, dynamic };
}

// A small lexical scan is enough to *recognize* direct literal calls. It is not
// a JS evaluator: aliases/expressions/escaped or interpolated paths remain
// unknown and conservative. Do not confuse imports, comments or prose with IO.
function jsDiscovery(source) {
  const tokens = [];
  for (let i = 0; i < source.length;) {
    const rest = source.slice(i), comment = /^(?:\/\/[^\n]*|\/\*[\s\S]*?\*\/|\s+)/.exec(rest);
    if (comment) { i += comment[0].length; continue; }
    if (source[i] === '/') {
      // Regex bodies may contain quotes. Never let one swallow a later IO call
      // as a string. Ambiguous division spans containing IO remain unknown.
      let end = i + 1, bracket = false;
      for (; end < source.length && source[end] !== '\n'; end++) {
        if (source[end] === '\\') { end++; continue; }
        if (source[end] === '[') bracket = true;
        if (source[end] === ']') bracket = false;
        if (source[end] === '/' && !bracket) break;
      }
      const previous = tokens.at(-1)?.value;
      const regex = !previous || ['(', '[', '{', ':', ',', '=', '!', '?', ';', 'return', 'case', '|', '&'].includes(previous)
        || previous === '>' && tokens.at(-2)?.value === '=';
      if (source[end] === '/') { tokens.push({value:source.slice(i, end + 1), expression:!regex}); i = end + 1; continue; }
    }
    const quote = source[i];
    if ('\'"`'.includes(quote)) {
      let value = '', simple = true, closed = false;
      for (i++; i < source.length; i++) {
        if (source[i] === quote) { i++; closed = true; break; }
        if (source[i] === '\\') { simple = false; value += source[i++] + (source[i] ?? ''); }
        else { if (quote === '`' && source[i] === '$' && source[i + 1] === '{') simple = false; value += source[i]; }
      }
      tokens.push({ value, literal: simple && closed, expression: quote === '`' && !simple });
      continue;
    }
    const word = /^[A-Za-z_$][\w$]*/.exec(rest);
    tokens.push({ value: word ? word[0] : source[i], identifier: Boolean(word) });
    i += word ? word[0].length : 1;
  }
  const names = new Map([['runLua', 'lua'], ['readdirSync', 'directory']]), ignored = new Set(), namespaces = new Set();
  for (let i = 0; i < tokens.length; i++) {
    if (tokens[i].value !== 'import' || tokens[i + 1]?.value === '(') continue;
    if (tokens[i + 1]?.value === '*' && tokens[i + 2]?.value === 'as' && tokens[i + 3]?.identifier) namespaces.add(tokens[i + 3].value);
    for (let j = i + 1; j < tokens.length; j++) {
      ignored.add(j);
      const kind = names.get(tokens[j].value);
      if (kind && tokens[j + 1]?.value === 'as' && tokens[j + 2]?.identifier) names.set(tokens[j + 2].value, kind);
      if (tokens[j].literal) break;
    }
  }
  const references = new Set(), directories = new Set();
  let dynamicLua = false, dynamicScript = false;
  // Expressions inside templates execute too. If the bounded scanner cannot
  // resolve such a call, retain it rather than treating the template as prose.
  for (const token of tokens) if (token.expression) {
    if ([...namespaces].some(name => token.value.includes(name))) { dynamicLua = true; dynamicScript = true; }
    for (const [name, kind] of names) if (token.value.includes(name)) {
      dynamicLua = true;
      if (kind === 'directory') dynamicScript = true;
    }
    if (/\bimport\s*\(/.test(token.value)) { dynamicLua = true; dynamicScript = true; }
  }
  for (let i = 0; i < tokens.length; i++) {
    const token = tokens[i];
    if (ignored.has(i)) continue;
    if (token.identifier && namespaces.has(token.value)) {
      const direct = tokens[i + 1]?.value === '.' && tokens[i + 2]?.identifier;
      const computed = tokens[i + 1]?.value === '[' && tokens[i + 2]?.literal && tokens[i + 3]?.value === ']';
      if (!direct && !computed) { dynamicLua = true; dynamicScript = true; }
      continue;
    }
    const receiver = tokens[i - 2];
    const member = receiver?.identifier && !['return', 'case', 'throw', 'yield', 'await', 'typeof', 'void', 'delete', 'new'].includes(receiver.value)
      || [')', ']', '.'].includes(receiver?.value);
    const computed = member && token.literal && tokens[i - 1]?.value === '[' && tokens[i + 1]?.value === ']';
    if (!token.identifier && !computed) continue;
    const kind = names.get(token.value);
    if (!kind && token.value !== 'import') continue;
    // Function declarations do not execute the declared function.
    if (tokens[i - 1]?.value === 'function') continue;
    const offset = computed ? 2 : 1;
    const argument = tokens[i + offset + 1], delimiter = tokens[i + offset + 2]?.value;
    const literalCall = tokens[i + offset]?.value === '(' && argument?.literal && [')', ','].includes(delimiter);
    if (token.value === 'import' && tokens[i + 1]?.value !== '(') continue;
    // Even a literal import() returns a namespace whose computed/aliased
    // consumption is not resolved here. Its static edge is still recorded below.
    if (token.value === 'import') { dynamicLua = true; dynamicScript = true; }
    if (literalCall) {
      const path = posix.normalize(slash(argument.value));
      if (kind === 'directory') directories.add(path.replace(/\/$/, ''));
      else if (kind === 'lua') references.add(path);
    } else if (kind === 'lua') dynamicLua = true;
    else { dynamicLua = true; dynamicScript = true; }
  }
  return { references, directories, dynamicLua, dynamicScript };
}
export function selectTests(changed, sources) {
  const paths = Object.keys(sources), deps = new Map(), integration = new Set(), dynamicImports = new Set(), dynamicScripts = new Set();
  for (const [module, producer] of Object.entries(generated)) {
    if (!(producer in sources)) continue;
    for (const directory of ['src/lua', 'build/lua']) deps.set(`${directory}/${module}.lua`, new Set([producer]));
  }
  const available = path => path in sources || deps.has(path);
  const js = paths.filter(p => /^tests\/[^/]+\.test\.mjs$/.test(p));
  const lua = paths.filter(p => /^tests\/lua\/[^/]+\.lua$/.test(p));
  const roots = [...js, ...lua];
  const fallback = reason => ({ full: true, reason, fast: [], integration: [], lua: [] });
  if (!changed.length) return fallback('No explicit change set; run the complete check');
  for (const path of changed) {
    if (!(path in sources) || !/^(src\/lua\/.*\.lua|scripts\/.*\.mjs|tests\/.*\.(mjs|lua))$/.test(path))
      return fallback(`Unmodelled or deleted input: ${path}`);
    if (/scripts\/(test-affected|test-lua|build-.*)\.mjs$/.test(path))
      return fallback(`Shared build/test infrastructure: ${path}`);
  }
  for (const [path, source] of Object.entries(sources)) {
    const references = new Set();
    // runLua's CLI discovers all fixtures, but importing runLua does not execute
    // that CLI. Its only layout injection is attached to the exact fixtures below.
    // Changes to this shared runner already force a complete check above.
    if (path === 'scripts/test-lua.mjs') {
      for (const match of source.matchAll(/from\s*['"](\.[^'"]+)['"]/g)) {
        const target = slash(relative(process.cwd(), resolve(dirname(path), match[1])));
        // Conditional setup belongs only to its exact fixtures below.
        if (conditionalRunnerFixtures.has(target)) continue;
        if (available(target)) references.add(target);
        else { dynamicImports.add(path); dynamicScripts.add(path); }
      }
      deps.set(path, references); integration.add(path); continue;
    }
    if (path.endsWith('.lua')) {
      const imports = luaImports(source);
      for (const target of imports.references) {
        if (available(target)) references.add(target);
        else dynamicImports.add(path);
      }
      if (imports.dynamic) dynamicImports.add(path);
      if (/^tests\/lua\/battle_ui(?:_slice_[2-7])?\.lua$/.test(path) && available('scripts/ui-layout.mjs')) references.add('scripts/ui-layout.mjs');
      for (const [helper, fixtures] of conditionalRunnerFixtures) {
        if (fixtures.has(path) && available(helper)) references.add(helper);
      }
    } else {
      const discovery = jsDiscovery(source);
      for (const target of discovery.references) {
        if (available(target)) references.add(target);
        else dynamicImports.add(path);
      }
      for (const directory of discovery.directories) {
        // Known directories have bounded dependencies. Unknown directory
        // expressions (including aliases) retain the conservative catch-all.
        if (directory === '.') { for (const target of paths) references.add(target); }
        else if (/^(?:src|scripts|tests|build\/lua)(?:\/|$)/.test(directory)
          && [...paths, ...deps.keys()].some(target => target.startsWith(`${directory}/`))) {
          for (const target of [...paths, ...deps.keys()]) if (target.startsWith(`${directory}/`)) references.add(target);
        } else { dynamicImports.add(path); dynamicScripts.add(path); }
      }
      if (discovery.dynamicLua) dynamicImports.add(path);
      if (discovery.dynamicScript) dynamicScripts.add(path);
      // Includes Lua embedded in JS fixture builders; runtime builders stay conservative below.
      for (const match of source.matchAll(/\b(?:require\s*\(?\s*|pcall\s*\(\s*require\s*,\s*)['"](abyss_\w+)['"]/g)) {
        const target = `src/lua/${match[1]}.lua`;
        if (available(target)) references.add(target);
        else dynamicImports.add(path);
      }
    }
    for (const match of source.matchAll(/(?:from\s*|import\s*\(?\s*)['"](\.[^'"]+)['"]/g)) {
      const target = slash(relative(process.cwd(), resolve(dirname(path), match[1])));
      if (available(target)) references.add(target);
      else { dynamicImports.add(path); dynamicScripts.add(path); }
    }
    for (const match of source.matchAll(/['"](\.\.?\/[^'"\n]+\.(?:mjs|lua))['"]/g)) {
      const target = slash(relative(process.cwd(), resolve(dirname(path), match[1])));
      if (available(target)) references.add(target);
    }
    for (const match of source.matchAll(/['"]((?:tests|scripts|src|build\/lua)\/[^'"\n]+\.(?:mjs|lua))['"]/g)) {
      if (available(match[1])) references.add(match[1]);
    }
    deps.set(path, references);
    if (/runLua|node:child_process|spawnSync|execFile|spawn\(/.test(source) || path.endsWith('.lua')) integration.add(path);
  }
  const closure = (start, runnerBoundary = false) => {
    const seen = new Set();
    function visit(path) {
      if (seen.has(path)) return;
      seen.add(path);
      if (runnerBoundary && path === 'scripts/test-lua.mjs') return;
      for (const dep of deps.get(path) ?? []) visit(dep);
    }
    visit(start); return seen;
  };
  const affected = new Set(changed), mapped = new Set(), selected = [];
  const luaChange = changed.some(p => p.endsWith('.lua')) || [...deps.keys()]
    .some(p => p.startsWith('build/lua/') && [...closure(p)].some(input => affected.has(input)));
  const scriptChange = changed.some(p => p.endsWith('.mjs'));
  for (const test of roots) {
    const dependencies = closure(test);
    // The imported runner API does not execute CLI-only discovery in its own
    // scheduling helpers. Preserve static import coverage without that taint.
    const runtimeDependencies = closure(test, true);
    for (const path of changed) if (dependencies.has(path)) mapped.add(path);
    // Dynamic Lua builders are conservatively included for every Lua change.
    // Literal dependency analysis must not silently omit generated test programs.
    const dynamicLua = luaChange && [...runtimeDependencies].some(p => dynamicImports.has(p));
    // Script-driven integration tests can discover sources/fixtures at runtime.
    // Keep these for every script change rather than guessing their dynamic IO.
    const dynamicScript = scriptChange && [...runtimeDependencies].some(p => dynamicScripts.has(p));
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

// An advisory subset only: the unchanged complete Quality suite owns coverage.
// Measured weights schedule complete fixtures; they never change fixture deadlines.
export function selectQuickFeedback(plan, changed, timings, budgetMs = 90000) {
  if (plan.full) return { fast: [], lua: [], estimatedLuaMs: 0 };
  const weight = path => Number.isFinite(timings.lua?.[path]) && timings.lua[path] > 0 ? timings.lua[path] : 30000;
  const direct = new Set(changed), lua = [];
  let estimatedLuaMs = 0;
  for (const path of [...plan.lua].sort((a, b) => Number(direct.has(b)) - Number(direct.has(a)) || weight(a) - weight(b) || a.localeCompare(b))) {
    if (estimatedLuaMs + weight(path) <= budgetMs) { lua.push(path); estimatedLuaMs += weight(path); }
  }
  return { fast: plan.fast, lua, estimatedLuaMs };
}

export function selectQuickPlan(changed, sources, fullPlan = selectTests(changed, sources)) {
  if (!fullPlan.full) return fullPlan;
  // Unknown inputs still require the complete gate. Independently mapped inputs
  // may provide advisory feedback without claiming coverage of those unknowns.
  const mapped = changed.filter(path => !selectTests([path], sources).full);
  return selectTests(mapped, sources);
}

function run(command, args) {
  const result = spawnSync(command, args, { stdio: 'inherit', windowsHide: true });
  if (result.error) throw result.error;
  if (result.status !== 0) throw new Error(`${command} failed (${result.status ?? result.signal})`);
}
export function parseGitChanges(output) {
  const fields = output.split('\0'), paths = [];
  if (fields.pop() !== '') throw new Error('Expected NUL-delimited git change records');
  for (let i = 0; i < fields.length;) {
    const status = fields[i++], count = /^[RC]\d+$/.test(status) ? 2 : /^[ACDMRTUXB]$/.test(status) ? 1 : 0;
    if (!count || i + count > fields.length) throw new Error('Invalid git change record');
    for (let j = 0; j < count; j++) {
      if (!fields[i]) throw new Error('Empty git change path');
      paths.push(fields[i++]);
    }
  }
  return paths;
}
export function main(args) {
  const ciFast = args.includes('--ci-fast');
  const planOnly = args.includes('--plan'), tier = ciFast ? 'ci-fast' : args.includes('--fast') ? 'fast' : 'related';
  const at = args.indexOf('--files');
  let changed;
  if (at >= 0) changed = args.slice(at + 1).filter(p => !p.startsWith('--')).map(slash);
  else {
    const base = args[args.indexOf('--base') + 1];
    if (!args.includes('--base') || !base) throw new Error('Provide --base <commit> or --files <paths...>; use --plan to inspect');
    const git = spawnSync('git', ['diff', '--name-status', '-z', '--find-renames', base, '--'], { encoding: 'utf8' });
    if (git.status !== 0) throw new Error(git.stderr || 'Cannot resolve comparison base');
    changed = parseGitChanges(git.stdout);
    const untracked = spawnSync('git', ['ls-files', '-z', '--others', '--exclude-standard'], { encoding: 'utf8' });
    if (untracked.status !== 0) throw new Error('Cannot inspect untracked inputs');
    changed.push(...untracked.stdout.split('\0').filter(Boolean));
  }
  const sources = Object.fromEntries(['src/lua', 'scripts', 'tests'].flatMap(files)
    .filter(p => /\.(lua|mjs)$/.test(p)).map(p => [p, readFileSync(p, 'utf8')]));
  const plan = selectTests([...new Set(changed)], sources);
  console.log(JSON.stringify({ tier, changed, ...plan }, null, 2));
  if (planOnly) return;
  const summary = message => {
    console.log(message);
    if (ciFast && process.env.GITHUB_STEP_SUMMARY) appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${message}\n\n`);
  };
  const quickPlan = ciFast ? selectQuickPlan(changed, sources, plan) : null;
  if (ciFast && plan.full) summary(`Complete Quality required: ${plan.reason}. Quick feedback covers only independently mapped inputs.`);
  if (ciFast && quickPlan.full) {
    summary('Quick feedback unavailable. No tests run here; parallel complete Quality is required.'); return;
  }
  const npm = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const npmRun = name => process.platform === 'win32'
    ? run('cmd.exe', ['/d', '/s', '/c', `npm run ${name}`]) : run(npm, ['run', name]);
  if (plan.full && !ciFast) { npmRun('check'); return; }
  const quick = ciFast ? selectQuickFeedback(quickPlan, changed,
    JSON.parse(readFileSync(new URL('./ci-test-timings.json', import.meta.url), 'utf8'))) : null;
  const tests = ciFast ? quick.fast : tier === 'fast' ? plan.fast : [...plan.fast, ...plan.integration];
  const fixtures = ciFast ? quick.lua : tier === 'fast' ? [] : plan.lua;
  if (ciFast) summary(`Advisory subset: ${tests.length} fast JS and ${fixtures.length} related Lua files selected; ${quickPlan.integration.length} integration JS and ${quickPlan.lua.length - fixtures.length} Lua files deferred to complete Quality. Lua scheduling estimate ${quick.estimatedLuaMs} ms, not a deadline.`);
  if (ciFast && !tests.length && !fixtures.length) {
    summary('No quick tests selected. Complete Quality remains required; this is not a regression pass.');
    return;
  }
  if (ciFast && tests.includes('tests/reviewed-traveler-geo-assets.test.mjs')) run(process.execPath, ['scripts/ci-reviewed-lfs.mjs']);
  if (ciFast) delete process.env.CI_LFS_TOKEN;
  npmRun('build:data'); npmRun('build:ui');
  if (tests.length) run(process.execPath, ['--test', '--test-concurrency=1', ...tests]);
  for (const fixture of fixtures) run(process.execPath, ['scripts/test-lua.mjs', fixture]);
  summary(`Completed ${tests.length} JS and ${fixtures.length} Lua files; full Quality remains required.`);
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { main(process.argv.slice(2)); } catch (error) { console.error(error.message); process.exitCode = 1; }
}
