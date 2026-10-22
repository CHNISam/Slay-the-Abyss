import { spawnSync } from 'node:child_process';
import { mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';
import { battleLayout } from './ui-layout.mjs';

export function buildUI(outputDirectory = 'build/lua', python = process.env.ABYSS_PYTHON || 'python') {
  const rendered = spawnSync(python, ['tools/render_traveler_cards.py', 'data/cards.json', 'data/presentation/traveler.zh-CN.json'],
    { encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024 });
  if (rendered.status !== 0) throw new Error(rendered.stderr || rendered.error?.message || 'Presentation renderer failed');
  const source = JSON.parse(rendered.stdout);
  const cards = Object.fromEntries(source.cards.map(card => [card.id, card]));
  mkdirSync(outputDirectory, { recursive: true });
  writeFileSync(join(outputDirectory, 'abyss_presentation.lua'), `-- Generated from the checked Traveler presentation.\nreturn ${toLua(cards)}\n`, 'utf8');
  writeFileSync(join(outputDirectory, 'battle-ui.json'), JSON.stringify(battleLayout(), null, 2) + '\n', 'utf8');
}
if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try { buildUI(process.argv[2]); console.log('Native battle UI and Traveler display module built.'); }
  catch (error) { console.error(error.message); process.exitCode = 1; }
}
