import {projectOpenPrSource} from './helpers/open-pr-source-composition.mjs';
import test from 'node:test';
import {historicalTest} from './helpers/historical-baseline-inputs.mjs';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gameLayout } from '../scripts/game-ui-layout.mjs';
import { nodeLayout } from '../scripts/node-ui-layout.mjs';
import { battleLayout } from '../scripts/ui-layout.mjs';
import { nativeTheme as theme } from '../scripts/native-ui-theme.mjs';
import { validateTheme } from '../scripts/build-ui-theme.mjs';
import { loadContent } from '../scripts/validate-data.mjs';
import { createHash } from 'node:crypto';
import { heroVisualProof, preHeroVisualSource } from './helpers/hero-visual-source-inverse.mjs';

historicalTest('the complete hero layer restores prior inputs and rejects partial or cross-path drift', () => {
  const hash = source => createHash('sha256').update(source).digest('hex');
  for (const [path, binding] of Object.entries(heroVisualProof.files)) {
    const source = projectOpenPrSource(path,readFileSync(path,'utf8'),'hero').replaceAll('\r\n', '\n');
    assert.equal(hash(source), binding.afterSha256, path);
    assert.equal(hash(binding.before), binding.beforeSha256, path);
    assert.equal(preHeroVisualSource(path, source), binding.before, path);
    assert.equal(preHeroVisualSource(path, source.replaceAll('\n', '\r\n')), binding.before, path);
    assert.equal(preHeroVisualSource(path, binding.before), binding.before, path);
    for (const changed of [source.slice(1), source + '\n-- drift\n'])
      assert.equal(preHeroVisualSource(path, changed), changed, path);
    assert.equal(preHeroVisualSource('unregistered.lua', source), source, path);
    assert.equal(preHeroVisualSource(path, null), null, path);
  }
});

const idOf = entry => (typeof entry === 'object' ? entry.id : entry);

test('hero slots are distinct library pictures and the battle bust is not the Geo icon', () => {
  const slots = theme.icon.heroSlots;
  const ids = new Map();
  const claim = (entry, fallback) => {
    const id = idOf(entry);
    assert.equal(Number.isInteger(id), true, fallback);
    assert.notEqual(id, theme.icon.geo, fallback);
    const previous = ids.get(id);
    if (previous) assert.equal(previous, entry.slot, `${fallback} reuses ${previous}`);
    else ids.set(id, entry.slot);
  };
  claim(slots.menu, 'menu');
  assert.equal(slots.menu.id, slots.large.traveler.ironclad.id);
  ids.set(slots.menu.id, slots.large.traveler.ironclad.slot);
  claim(theme.icon.player, 'battle');
  assert.notEqual(theme.icon.player.id, slots.menu.id);
  assert.equal(theme.icon.player.owner, 'dot-b');
  assert.equal(theme.icon.player.status, 'placeholder');
  for (const group of [slots.large, slots.bust]) {
    for (const entry of Object.values(group)) {
      if (entry.id) claim(entry, entry.slot);
      else for (const child of Object.values(entry)) claim(child, child.slot);
    }
  }
  for (const portrait of Object.values(theme.icon.characterPortraits)) {
    assert.equal(portrait.placeholder, true);
    assert.notEqual(portrait.id, theme.icon.geo);
  }
  assert.deepEqual(validateTheme(theme, loadContent('data')), []);
});

test('menu hero, select busts and Neow figure are wired without sharing one traveler image', () => {
  const menu = gameLayout().controls.find(control => control.name === 'menuPanel');
  const hero = menu.children.find(control => control.name === 'heroArt');
  assert.equal(hero.image, theme.icon.heroSlots.menu.id);
  assert.equal(hero.colour, theme.color.buttonPressedText);
  const [w, h] = theme.canvas.base;
  const { x, y } = theme.canvas.safe;
  const frame = theme.layout.nativeMenu.hero;
  assert.ok(Math.abs(frame[0]) + frame[2] / 2 <= w / 2 - x);
  assert.ok(Math.abs(frame[1]) + frame[3] / 2 <= h / 2 - y);
  const select = gameLayout().controls.find(control => control.name === 'characterPanel');
  const portraits = select.children.find(control => control.name === 'details').children.find(control => control.name === 'portraits');
  const shown = portraits.children.filter(child => child.visible);
  assert.deepEqual(shown.map(child => child.name), ['traveler_ironclad']);
  const images = new Set(portraits.children.map(child => child.image));
  assert.equal(images.size, portraits.children.length);
  const traveler = select.children.find(control => control.name === 'traveler');
  assert.equal(traveler.children.find(control => control.name === 'hit').children[0].children
    .find(child => child.name === 'bust').image, theme.icon.heroSlots.bust.traveler.ironclad.id);
  const event = nodeLayout().controls[0].children.find(control => control.name === 'eventView');
  const figure = event.children.find(control => control.name === 'neowFigure');
  assert.equal(figure.visible, false);
  assert.deepEqual(figure.children.map(child => child.name), ['scene', 'shade', 'npc']);
  const heroUnit = battleLayout().controls.find(control => control.name === 'stage').children
    .find(control => control.name === 'hero');
  assert.equal(heroUnit.children.find(control => control.name === 'portrait').image, theme.icon.player.id);
  assert.notEqual(theme.icon.player.id, 102005);
  assert.equal(readFileSync('src/lua/abyss_game_ui.lua', 'utf8').includes('self.prologue:play()'), false);
});
