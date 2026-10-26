import { buildOriginalV4, loadOriginalV4 } from './build-original-v4.mjs';
import { mkdirSync, realpathSync, statSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, resolve, join, basename } from 'node:path';
import { pathToFileURL } from 'node:url';
import { contentFiles, loadContent, validateContent } from './validate-data.mjs';

function rejectInputOutputAlias(inputDirectory, output) {
  let outputStat;
  let outputRealPath;
  try {
    // Preserve the same symlink/.. traversal semantics as writeFileSync(output).
    outputStat = statSync(output, { bigint: true });
    outputRealPath = realpathSync.native(output);
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
  }
  const inputs = [...contentFiles];
  if (existsSync(resolve(inputDirectory,'original_v4'))) inputs.push('original_v4/cards_v4','original_v4/rules_v4');
  if (existsSync(resolve(inputDirectory, 'catalogs/sts1-relic-queues.json'))) inputs.push('catalogs/sts1-relic-queues');
  if (existsSync(resolve(inputDirectory, 'catalogs/sts1-acts234.json'))) inputs.push('catalogs/sts1-acts234');
  const inputPaths = inputs.map(file => resolve(inputDirectory, `${file}.json`));
  // Act2 source identity validation reads the repository's pinned catalog even
  // for a temporary bundle; protect that canonical input as well as local copies.
  const actCatalog = new URL('../data/catalogs/sts1-acts234.json', import.meta.url);
  if (existsSync(actCatalog)) inputPaths.push(actCatalog);
  for (const inputPath of inputPaths) {
    const inputStat = statSync(inputPath, { bigint: true });
    if (outputRealPath === realpathSync.native(inputPath) ||
        (outputStat && outputStat.dev === inputStat.dev && outputStat.ino === inputStat.ino)) {
      throw new Error(`Output must not overwrite an input file: ${inputPath}`);
    }
  }
}

export function luaString(value) {
  if (!value.isWellFormed()) throw new TypeError('Lua strings require well-formed Unicode');
  // Fixed-width byte escapes prevent a following digit from joining an escape.
  return '"' + [...Buffer.from(value, 'utf8')].map(byte =>
    byte >= 32 && byte <= 126 && byte !== 34 && byte !== 92
      ? String.fromCharCode(byte) : `\\${String(byte).padStart(3, '0')}`).join('') + '"';
}

export function toLua(value) {
  if (typeof value === 'string') return luaString(value);
  if (typeof value === 'boolean') return String(value);
  if (typeof value === 'number' && Number.isFinite(value)) return String(value);
  if (Array.isArray(value)) return `{${value.map(toLua).join(',')}}`;
  if (value !== null && typeof value === 'object') {
    return `{${Object.keys(value).sort().map(key => `[${luaString(key)}]=${toLua(value[key])}`).join(',')}}`;
  }
  throw new TypeError(`Unsupported Lua data value: ${String(value)}`);
}

export function buildLuaData(inputDirectory = 'data', output = 'build/lua/abyss_data.lua') {
  const data = loadContent(inputDirectory);
  const errors = validateContent(data);
  if (errors.length) throw new Error(errors.join('\n'));
  rejectInputOutputAlias(inputDirectory, output);
  const originalDirectory=resolve(inputDirectory,'original_v4');
  const original=existsSync(originalDirectory);
  if (original) {
    if (basename(output).toLowerCase()==='abyss_original_v4_data.lua') throw new Error('Output collides with generated Original V4 module');
    loadOriginalV4(originalDirectory);
  }
  const source = `-- Generated from validated JSON. Do not edit.\nreturn ${toLua(data)}\n`;
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, source, 'utf8');
  if (original) buildOriginalV4(originalDirectory,join(dirname(output),'abyss_original_v4_data.lua'));
  return source;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (process.argv.length > 4) throw new Error('Usage: node scripts/build-lua-data.mjs [data-directory] [output-file]');
    buildLuaData(process.argv[2], process.argv[3]);
    console.log('Validated Lua data module built.');
  } catch (error) { console.error(`Lua data build failed: ${error.message}`); process.exitCode = 1; }
}
