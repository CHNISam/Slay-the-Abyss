import { createHash } from 'node:crypto';
import { lstatSync, readFileSync, readdirSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import { basename, dirname, extname, isAbsolute, join, relative, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

const hash = bytes => createHash('sha256').update(bytes).digest('hex');
const normalize = text => text.replace(/^\uFEFF/, '').replace(/\r\n/g, '\n');
const reserved = /^(con|prn|aux|nul|com[1-9]|lpt[1-9])$/i;
const safeModule = value => typeof value === 'string' && /^[A-Za-z_][A-Za-z0-9_]*$/.test(value) && !reserved.test(value);
const safeFile = value => typeof value === 'string' && /^[A-Za-z_][A-Za-z0-9_]*\.lua$/i.test(value) && safeModule(value.slice(0, -4));
const key = value => value.toLowerCase();
function sourceHashes(bytes) {
  // ignoreBOM preserves it for the explicitly limited normalization below.
  const text = new TextDecoder('utf-8', { fatal: true, ignoreBOM: true }).decode(bytes);
  return { rawSha256: hash(bytes), normalizedSha256: hash(Buffer.from(normalize(text), 'utf8')) };
}
function inside(parent, child) {
  const path = relative(parent, child);
  return path === '' || !path.startsWith('..' + (process.platform === 'win32' ? '\\' : '/')) && path !== '..' && !isAbsolute(path);
}
function canonical(path) {
  try { return realpathSync.native(path); }
  catch (error) {
    if (error.code !== 'ENOENT') throw error;
    const parent = dirname(path);
    if (parent === path) throw error;
    return join(canonical(parent), basename(path));
  }
}

export function verifyOfficialClient(inventory, officialMapPath) {
  const report = { schemaVersion: 1, candidateMapPath: inventory?.mapPath ?? null,
    officialMapPath: resolve(officialMapPath), sidecarDirectory: resolve(dirname(officialMapPath), 'external_lua_file'),
    entry: 'abyss_ui', normalization: 'UTF-8 BOM at start and CRLF -> LF only',
    scope: 'Lua source equality only; not ready, playable, imported UI parity or gameplay acceptance.',
    ok: false, modules: [], unexpected: [], issues: [] };
  const issue = (code, message, file) => report.issues.push({ code, ...(file ? { file } : {}), message });
  if (!inventory || typeof inventory.mapPath !== 'string' || !inventory.mapPath.trim() || !Array.isArray(inventory.scripts)) {
    issue('INVALID_INVENTORY', 'Expected independent readback {mapPath, scripts:[{name,file,source}]}');
    return report;
  }
  const names = new Set(), files = new Set(), valid = [];
  for (const script of inventory.scripts) {
    if (!script || !safeModule(script.name) || !safeFile(script.file)) {
      issue('UNSAFE_SCRIPT_IDENTITY', 'Module and file must be simple non-reserved Lua identifiers/filenames');
      continue;
    }
    if (names.has(key(script.name)) || files.has(key(script.file))) {
      issue('DUPLICATE_MODULE', `Duplicate module or filename: ${script.name}`, script.file);
      continue;
    }
    names.add(key(script.name)); files.add(key(script.file));
    if (script.file !== script.name + '.lua') {
      issue('MODULE_FILE_MISMATCH', 'Module name must match its Lua filename exactly', script.file);
      continue;
    }
    if (typeof script.source !== 'string' || !script.source.isWellFormed()) {
      issue('MISSING_EMBEDDED_SOURCE', 'Independent inventory must include a valid UTF-8 source string', script.file);
      continue;
    }
    valid.push(script);
  }
  if (!valid.some(script => script.name === 'abyss_ui' && script.file === 'abyss_ui.lua'))
    issue('MISSING_ENTRY', 'Candidate inventory must include abyss_ui.lua with embedded source');
  // Reject invalid inventory before looking at any of its requested files.
  if (report.issues.length) return report;
  try {
    if (extname(report.officialMapPath).toLowerCase() !== '.gil' || !lstatSync(report.officialMapPath).isFile())
      throw new Error('Expected a regular official .gil file');
  } catch (error) { issue('INVALID_OFFICIAL_MAP', error.message); return report; }
  let entries;
  try {
    const info = lstatSync(report.sidecarDirectory);
    if (!info.isDirectory() || info.isSymbolicLink()) throw new Error('Sidecar directory must be a regular directory');
    entries = readdirSync(report.sidecarDirectory, { withFileTypes: true });
  } catch (error) {
    issue('MISSING_SIDECAR_DIRECTORY', error.message);
    for (const script of valid) report.modules.push({ name: script.name, file: script.file, status: 'missing',
      embedded: sourceHashes(Buffer.from(script.source, 'utf8')), external: null });
    return report;
  }
  const actual = new Map();
  for (const entry of entries) {
    // Non-Lua files are neither opened nor hashed. Directory listings only.
    if (!/\.lua$/i.test(entry.name)) continue;
    if (!safeFile(entry.name)) {
      issue('UNSAFE_EXTERNAL_FILENAME', 'Unsafe Lua filename in sidecar directory');
      continue;
    }
    if (actual.has(key(entry.name))) issue('DUPLICATE_EXTERNAL_MODULE', 'Case-insensitive duplicate external Lua filename', entry.name);
    actual.set(key(entry.name), entry);
  }
  function externalSource(entry) {
    const path = join(report.sidecarDirectory, entry.name);
    try {
      if (!entry.isFile() || entry.isSymbolicLink() || lstatSync(path).isSymbolicLink()) {
        issue('UNSAFE_EXTERNAL_FILE', 'External Lua must be a regular file, not a link or directory', entry.name);
        return null;
      }
      if (!inside(realpathSync.native(report.sidecarDirectory), realpathSync.native(path))) {
        issue('UNSAFE_EXTERNAL_FILE', 'Resolved Lua path escapes sidecar directory', entry.name);
        return null;
      }
      return sourceHashes(readFileSync(path));
    } catch (error) {
      issue('UNREADABLE_EXTERNAL_SOURCE', error.message, entry.name);
      return null;
    }
  }
  for (const script of valid) {
    const embedded = sourceHashes(Buffer.from(script.source, 'utf8'));
    const entry = actual.get(key(script.file));
    if (!entry) {
      report.modules.push({ name: script.name, file: script.file, status: 'missing', embedded, external: null });
      issue('MISSING_MODULE', 'Expected external Lua module is missing', script.file);
      continue;
    }
    const external = externalSource(entry);
    const status = !external ? 'unreadable' : embedded.normalizedSha256 === external.normalizedSha256 ? 'match' : 'diff';
    report.modules.push({ name: script.name, file: script.file, actualFile: entry.name, status, embedded, external });
    if (status === 'diff') issue('SOURCE_DIFF', 'External Lua differs from candidate embedded source', script.file);
  }
  for (const [file, entry] of actual) if (!files.has(file)) {
    report.unexpected.push({ file: entry.name, status: 'unexpected', external: externalSource(entry) });
    issue('UNEXPECTED_MODULE', 'External Lua is absent from candidate inventory', entry.name);
  }
  report.ok = report.issues.length === 0;
  return report;
}

export function runOfficialClientCli(args, output = process.stdout, errors = process.stderr) {
  const [inventoryFile, officialMapPath, reportFile] = args;
  if (args.length < 2 || args.length > 3) {
    errors.write('Usage: node scripts/verify-official-client.mjs <candidate-scripts.json> <official.gil> [report.json]\n');
    return 1;
  }
  try {
    const inventoryBytes = readFileSync(inventoryFile);
    const inventory = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(inventoryBytes));
    // Explicit report output may never mutate the official save, its sidecars,
    // the independent inventory or the candidate named by that inventory.
    if (reportFile) {
      const destination = canonical(resolve(reportFile));
      const input = canonical(resolve(inventoryFile));
      if (extname(destination).toLowerCase() !== '.json' || inside(canonical(resolve(dirname(officialMapPath))), destination) ||
          destination === input || inventory?.mapPath && destination === canonical(resolve(inventory.mapPath)))
        throw new Error('Report must be a separate .json file outside the official save directory and source inputs');
      try {
        const target = statSync(destination), source = statSync(input);
        if (target.nlink > 1) throw new Error('Report must not overwrite a linked file');
        if (target.dev === source.dev && target.ino === source.ino) throw new Error('Report aliases inventory');
      } catch (error) { if (error.code !== 'ENOENT') throw error; }
    }
    const report = verifyOfficialClient(inventory, officialMapPath);
    report.inventory = { path: resolve(inventoryFile), rawSha256: hash(inventoryBytes) };
    if (reportFile) writeFileSync(reportFile, JSON.stringify(report, null, 2) + '\n');
    const summary = { ok: report.ok, modules: report.modules.length,
      matched: report.modules.filter(module => module.status === 'match').length,
      missing: report.modules.filter(module => module.status === 'missing').map(module => module.file),
      diff: report.modules.filter(module => module.status === 'diff').map(module => module.file),
      unexpected: report.unexpected.map(module => module.file), issues: report.issues, scope: report.scope };
    output.write(JSON.stringify(summary, null, 2) + '\n');
    return report.ok ? 0 : 1;
  } catch (error) { errors.write(`Official client source verification failed: ${error.message}\n`); return 1; }
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href)
  process.exitCode = runOfficialClientCli(process.argv.slice(2));
