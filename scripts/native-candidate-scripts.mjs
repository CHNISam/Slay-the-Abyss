import { readdirSync, statSync } from 'node:fs';
import { resolve, basename } from 'node:path';

// Only outputs consumed by the game are deployable. Test bridges also write
// Lua into build/lua; discovering every .lua there ships test fixtures.
const generatedModules = ['abyss_art_features','abyss_data', 'abyss_original_v4_data', 'abyss_map_layout', 'abyss_narrative', 'abyss_presentation', 'abyss_theme', 'abyss_menu_background_asset', 'abyss_ready_card_binding', 'abyss_ready_card_assets', 'abyss_traveler_portrait_assets'];
// Legacy LCG is superseded by the StS RNG modules. Keep its source/tests;
// check:platform-load proves no production import references this exclusion.
export const excludedProductionModules = ['abyss_random'];

export function nativeUiVariables() {
  return [
    {name:'nativeBgmEnabled',type:'boolean',value:false},
    {name:'experimentalCharacters',type:'boolean',value:false},
  ];
}

export function candidateScriptFiles(sourceDirectory = 'src/lua', generatedDirectory = 'build/lua', generated = generatedModules) {
  const files = readdirSync(sourceDirectory, { withFileTypes: true })
    .filter(entry => entry.isFile() && entry.name.endsWith('.lua') && !excludedProductionModules.includes(basename(entry.name, '.lua')))
    .map(entry => resolve(sourceDirectory, entry.name));
  for (const name of generated) {
    if (files.some(file => basename(file, '.lua') === name)) throw Error(`Duplicate game module: ${name}`);
    const file = resolve(generatedDirectory, `${name}.lua`);
    if (!statSync(file).isFile()) throw Error(`Missing generated game module: ${name}`);
    files.push(file);
  }
  const names = new Set();
  return files.sort().map(file => {
    const name = basename(file, '.lua');
    if (names.has(name)) throw Error(`Duplicate game module: ${name}`);
    names.add(name);
    return { name, sourceFile: file,
      ...(name === 'abyss_ui' ? { variables: nativeUiVariables() } : {}) };
  });
}
