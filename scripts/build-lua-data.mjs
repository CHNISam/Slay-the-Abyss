import { mkdirSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { loadContent, validateContent } from './validate-data.mjs';

export function luaString(value) {
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
  const source = `-- Generated from validated JSON. Do not edit.\nreturn ${toLua(data)}\n`;
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, source, 'utf8');
  return source;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (process.argv.length > 4) throw new Error('Usage: node scripts/build-lua-data.mjs [data-directory] [output-file]');
    buildLuaData(process.argv[2], process.argv[3]);
    console.log('Validated Lua data module built.');
  } catch (error) { console.error(`Lua data build failed: ${error.message}`); process.exitCode = 1; }
}
