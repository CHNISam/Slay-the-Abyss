import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, realpathSync, statSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';
import { battleLayout } from './ui-layout.mjs';
import { gameLayout } from './game-ui-layout.mjs';
import { withViewport } from './viewport-layout.mjs';
import { buildUiTheme } from './build-ui-theme.mjs';
import { buildMapUI } from './map-ui-layout.mjs';
import { deckCardTemplate } from './deck-ui-layout.mjs';
import { contentFiles } from './validate-data.mjs';

export function assertNativeUiCapacity(layout) {
  const visit = (controls, path) => {
    if (controls.length > 60) throw new Error(`${path}: ${controls.length} direct children exceeds the platform limit of 60`);
    for (const control of controls) visit(control.children ?? [], `${path}/${control.name}`);
  };
  visit(layout.controls ?? layout.children ?? [], layout.name ?? 'native UI');
}

function rejectInputOutputAliases(outputDirectory) {
  const inputs = [...contentFiles.map(file => resolve('data', `${file}.json`)),
    resolve('data/presentation/ui_theme.json'), resolve('data/presentation/traveler.zh-CN.json'),
    resolve('data/presentation/narrative.zh-CN.json'),
    // Imported battle/native layout modules read this theme relative to their source.
    fileURLToPath(new URL('../data/presentation/ui_theme.json', import.meta.url))];
  const identities = inputs.map(input => ({ input, realPath: realpathSync.native(input),
    stat: statSync(input, { bigint: true }) }));
  const outputs = ['abyss_theme.lua', 'map-ui.json', 'abyss_map_layout.lua', 'abyss_map_controls.lua',
    'abyss_narrative.lua', 'abyss_presentation.lua', 'battle-ui.json', 'game-ui.json', 'abyss_ui_layout.lua',
    'game-ui-templates.json', 'abyss_ui_templates.lua'];
  for (const file of outputs) {
    const output = join(outputDirectory, file);
    let outputStat, outputRealPath;
    try {
      // Match the actual IO identity, as in the standalone Lua exporters.
      outputStat = statSync(output, { bigint: true });
      outputRealPath = realpathSync.native(output);
    } catch (error) {
      if (error.code === 'ENOENT') continue;
      throw error;
    }
    for (const { input, realPath, stat } of identities) {
      if (outputRealPath === realPath || (outputStat.dev === stat.dev && outputStat.ino === stat.ino)) {
        throw new Error(`Output must not overwrite an input file: ${input}`);
      }
    }
  }
}

export function buildUI(outputDirectory = 'build/lua', python = process.env.ABYSS_PYTHON || 'python') {
  // Preflight the entire batch before any generated file can be changed.
  rejectInputOutputAliases(outputDirectory);
  const theme = JSON.parse(readFileSync('data/presentation/ui_theme.json', 'utf8').replace(/^\uFEFF/, ''));
  const battle = battleLayout(), layout = withViewport(gameLayout(), theme);
  const templates = [deckCardTemplate()];
  for (const tree of [battle, layout, ...templates]) assertNativeUiCapacity(tree);
  const rendered = spawnSync(python, ['tools/render_traveler_cards.py', 'data/cards.json', 'data/presentation/traveler.zh-CN.json'],
    { encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } });
  if (rendered.status !== 0) throw new Error(rendered.stderr || rendered.error?.message || 'Presentation renderer failed');
  const source = JSON.parse(rendered.stdout);
  const cards = Object.fromEntries(source.cards.map(card => [card.id, card]));
  mkdirSync(outputDirectory, { recursive: true });
  buildUiTheme(undefined, undefined, join(outputDirectory, 'abyss_theme.lua'));
  buildMapUI(outputDirectory);
  const narrative = JSON.parse(readFileSync('data/presentation/narrative.zh-CN.json', 'utf8'));
  writeFileSync(join(outputDirectory, 'abyss_narrative.lua'), `-- Generated from the approved narrative copy source.\nreturn ${toLua(narrative)}\n`, 'utf8');
  writeFileSync(join(outputDirectory, 'abyss_presentation.lua'), `-- Generated from the checked Traveler presentation.\nreturn ${toLua(cards)}\n`, 'utf8');
  writeFileSync(join(outputDirectory, 'battle-ui.json'), JSON.stringify(battle, null, 2) + '\n', 'utf8');
  writeFileSync(join(outputDirectory, 'game-ui.json'), JSON.stringify(layout, null, 2) + '\n', 'utf8');
  writeFileSync(join(outputDirectory, 'abyss_ui_layout.lua'), `-- Native layout fixture generated from the import tree.\nreturn ${toLua(layout.controls)}\n`, 'utf8');
  writeFileSync(join(outputDirectory, 'game-ui-templates.json'), JSON.stringify(templates, null, 2) + '\n', 'utf8');
  writeFileSync(join(outputDirectory, 'abyss_ui_templates.lua'), `-- Native template fixtures generated from the import tree.\nreturn ${toLua(Object.fromEntries(templates.map(template => [template.name, template])))}\n`, 'utf8');
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { buildUI(process.argv[2]); console.log('Native battle UI and Traveler display module built.'); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
