import { readdirSync, statSync } from 'node:fs';
import { resolve, basename } from 'node:path';

// Only outputs consumed by the game are deployable. Test bridges also write
// Lua into build/lua; discovering every .lua there ships test fixtures.
const generatedModules = ['abyss_data', 'abyss_map_layout', 'abyss_narrative', 'abyss_presentation', 'abyss_theme'];

export function candidateScriptFiles(sourceDirectory = 'src/lua', generatedDirectory = 'build/lua') {
  const files = readdirSync(sourceDirectory, { withFileTypes: true })
    .filter(entry => entry.isFile() && entry.name.endsWith('.lua'))
    .map(entry => resolve(sourceDirectory, entry.name));
  for (const name of generatedModules) {
    const file = resolve(generatedDirectory, `${name}.lua`);
    if (!statSync(file).isFile()) throw Error(`Missing generated game module: ${name}`);
    files.push(file);
  }
  const names = new Set();
  return files.sort().map(file => {
    const name = basename(file, '.lua');
    if (names.has(name)) throw Error(`Duplicate game module: ${name}`);
    names.add(name);
    return { name, sourceFile: file };
  });
}
