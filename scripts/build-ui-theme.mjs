import { mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { toLua } from './build-lua-data.mjs';
import { loadContent } from './validate-data.mjs';

// Id ranges of the platform picture library (image_catalog of the miliastra MCP, photographed 2026-10-13).
export const imageRanges = [
  [100001, 100006], [100101, 100213], [101001, 101080], [102001, 102052], [103001, 103148], [104001, 104010],
  [105001, 105317], [106001, 106096], [107001, 107402], [108001, 108020], [109001, 109075], [110001, 110053],
  [111001, 111139], [112001, 112077], [113001, 113002]];
const colourPattern = /^#[0-9A-Fa-f]{6}([0-9A-Fa-f]{2})?$/;

export function colourToLua(hex) {
  const value = (index) => parseInt(hex.slice(index, index + 2), 16);
  return { r: value(1), g: value(3), b: value(5), a: hex.length === 9 ? value(7) : 255 };
}

const isImage = id => Number.isInteger(id) && imageRanges.some(([low, high]) => id >= low && id <= high);
const iconId = entry => (entry !== null && typeof entry === 'object' ? entry.id : entry);

function walk(value, path, visit) {
  visit(value, path);
  if (value !== null && typeof value === 'object') for (const [key, child] of Object.entries(value)) walk(child, `${path}.${key}`, visit);
}

function requireIcons(errors, table, ids, label) {
  for (const id of ids) if (!isImage(iconId(table?.[id]))) errors.push(`icon.${label} has no picture for ${id}`);
}

export function validateTheme(theme, content) {
  const errors = [];
  walk(theme.color, 'color', (value, path) => {
    if (typeof value === 'string' && !colourPattern.test(value)) errors.push(`${path} is not #RRGGBB or #RRGGBBAA`);
  });
  for (const [name, size] of Object.entries(theme.font)) {
    if (!Number.isInteger(size) || size < theme.font.minimum) errors.push(`font.${name} is below the readable minimum`);
  }
  walk({ image: theme.image, icon: theme.icon }, 'theme', (value, path) => {
    if (typeof value === 'number' && !path.endsWith('.id') && !isImage(value)) errors.push(`${path} is not in the picture library`);
    if (value !== null && typeof value === 'object' && 'id' in value && !isImage(value.id)) errors.push(`${path}.id is not in the picture library`);
  });
  const [width, height] = theme.canvas.base;
  for (const [device, [w, h]] of Object.entries(theme.canvas.devices)) {
    if (Math.min(w / width, h / height) < 1) errors.push(`canvas.${device} is smaller than the base canvas`);
  }
  requireIcons(errors, theme.icon.enemy, content.enemies.enemies.map(enemy => enemy.id), 'enemy');
  requireIcons(errors, theme.icon.status, content.statuses.statuses.map(status => status.id), 'status');
  requireIcons(errors, theme.icon.potion, content.potions.potions.map(potion => potion.id), 'potion');
  requireIcons(errors, theme.icon.relic, content.relics.relics.map(relic => relic.id), 'relic');
  requireIcons(errors, theme.icon.node, content.rules.map.nodeTypes, 'node');
  return errors;
}

// Colours become 0-255 tables because the client API's Color() takes 0-255, not 0-1.
function convertColours(value) {
  if (typeof value === 'string' && colourPattern.test(value)) return colourToLua(value);
  if (Array.isArray(value)) return value.map(convertColours);
  if (value !== null && typeof value === 'object') return Object.fromEntries(Object.entries(value).map(([k, v]) => [k, convertColours(v)]));
  return value;
}

export function buildUiTheme(themeFile = 'data/presentation/ui_theme.json', dataDirectory = 'data', output = 'build/lua/abyss_theme.lua') {
  const theme = JSON.parse(readFileSync(themeFile, 'utf8').replace(/^﻿/, ''));
  const errors = validateTheme(theme, loadContent(dataDirectory));
  if (errors.length) throw new Error(errors.join('\n'));
  const { note, ...runtime } = theme;
  const source = `-- Generated from data/presentation/ui_theme.json. Do not edit.\nreturn ${toLua(convertColours(runtime))}\n`;
  mkdirSync(dirname(output), { recursive: true });
  writeFileSync(output, source, 'utf8');
  return source;
}

if (process.argv[1] && import.meta.url === pathToFileURL(resolve(process.argv[1])).href) {
  try {
    if (process.argv.length > 5) throw new Error('Usage: node scripts/build-ui-theme.mjs [theme-file] [data-directory] [output-file]');
    buildUiTheme(...process.argv.slice(2));
    console.log('UI theme Lua module built.');
  } catch (error) { console.error(`UI theme build failed: ${error.message}`); process.exitCode = 1; }
}
