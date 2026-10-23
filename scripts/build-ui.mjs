import { spawnSync } from 'node:child_process';
import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';
import { battleLayout } from './ui-layout.mjs';
import { gameLayout } from './game-ui-layout.mjs';
import { withViewport } from './viewport-layout.mjs';
import { buildUiTheme } from './build-ui-theme.mjs';
import { buildMapUI } from './map-ui-layout.mjs';
import { deckCardTemplate } from './deck-ui-layout.mjs';

export function buildUI(outputDirectory = 'build/lua', python = process.env.ABYSS_PYTHON || 'python') {
  const rendered = spawnSync(python, ['tools/render_traveler_cards.py', 'data/cards.json', 'data/presentation/traveler.zh-CN.json'],
    { encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } });
  if (rendered.status !== 0) throw new Error(rendered.stderr || rendered.error?.message || 'Presentation renderer failed');
  const source = JSON.parse(rendered.stdout);
  const cards = Object.fromEntries(source.cards.map(card => [card.id, card]));
  mkdirSync(outputDirectory, { recursive: true });
  const theme = JSON.parse(readFileSync('data/presentation/ui_theme.json', 'utf8').replace(/^\uFEFF/, ''));
  buildUiTheme(undefined, undefined, join(outputDirectory, 'abyss_theme.lua'));
  buildMapUI(outputDirectory);
  const narrative = JSON.parse(readFileSync('data/presentation/narrative.zh-CN.json', 'utf8'));
  writeFileSync(join(outputDirectory, 'abyss_narrative.lua'), `-- Generated from the approved narrative copy source.\nreturn ${toLua(narrative)}\n`, 'utf8');
  writeFileSync(join(outputDirectory, 'abyss_presentation.lua'), `-- Generated from the checked Traveler presentation.\nreturn ${toLua(cards)}\n`, 'utf8');
  writeFileSync(join(outputDirectory, 'battle-ui.json'), JSON.stringify(battleLayout(), null, 2) + '\n', 'utf8');
  const layout = withViewport(gameLayout(), theme);
  writeFileSync(join(outputDirectory, 'game-ui.json'), JSON.stringify(layout, null, 2) + '\n', 'utf8');
  writeFileSync(join(outputDirectory, 'abyss_ui_layout.lua'), `-- Native layout fixture generated from the import tree.\nreturn ${toLua(layout.controls)}\n`, 'utf8');
  const templates = [deckCardTemplate()];
  writeFileSync(join(outputDirectory, 'game-ui-templates.json'), JSON.stringify(templates, null, 2) + '\n', 'utf8');
  writeFileSync(join(outputDirectory, 'abyss_ui_templates.lua'), `-- Native template fixtures generated from the import tree.\nreturn ${toLua(Object.fromEntries(templates.map(template => [template.name, template])))}\n`, 'utf8');
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { buildUI(process.argv[2]); console.log('Native battle UI and Traveler display module built.'); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
