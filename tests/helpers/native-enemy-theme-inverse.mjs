// Test-only exact outer inverse. Live native portrait tests use the real theme.
// Preserve every accepted historical byte; unknown source remains unprojected.
import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
const hash = source => createHash('sha256').update(source).digest('hex');
export const nativeEnemyThemeLayer = Object.freeze({
  path: 'data/presentation/ui_theme.json',
  beforeSha256: 'ab06b7748903894fa447c290db6ee98fe8a4bf445f7a83c0be4a86603ff9bf5a',
  afterSha256: '3842999dc155ba9de00ac2b512d4a17b8e974292e8441626a379ab4058ee36b3',
  before: "    \"enemy\": {\n      \"cultist\": 112022,\n      \"jaw_worm\": 112038,\n      \"red_louse\": 112013,\n      \"green_louse\": 112014,\n      \"acid_slime_s\": 112009,\n      \"acid_slime_m\": 112009,\n      \"acid_slime_l\": 112010,\n      \"spike_slime_s\": 112007,\n      \"spike_slime_m\": 112007,\n      \"spike_slime_l\": 112008,\n      \"looter\": 112030,\n      \"blue_slaver\": 112031,\n      \"red_slaver\": 112050,\n      \"fungi_beast\": 112033,\n      \"mad_gremlin\": 112023,\n      \"sneaky_gremlin\": 112025,\n      \"fat_gremlin\": 112024,\n      \"wizard_gremlin\": 112034,\n      \"shield_gremlin\": 112036,\n      \"gremlin_nob\": 112037,\n      \"lagavulin\": 112026,\n      \"sentry\": 112027,\n      \"guardian\": 112046,\n      \"verify\": true\n    },",
  after: "    \"enemy\": {\n      \"cultist\": 112022,\n      \"jaw_worm\": 112038,\n      \"red_louse\": 112013,\n      \"green_louse\": 112014,\n      \"acid_slime_s\": 112009,\n      \"acid_slime_m\": 112009,\n      \"acid_slime_l\": 112010,\n      \"spike_slime_s\": 112007,\n      \"spike_slime_m\": 112007,\n      \"spike_slime_l\": 112008,\n      \"looter\": 112030,\n      \"blue_slaver\": 112031,\n      \"red_slaver\": 112050,\n      \"fungi_beast\": 112033,\n      \"mad_gremlin\": 112022,\n      \"sneaky_gremlin\": 112025,\n      \"fat_gremlin\": 112023,\n      \"wizard_gremlin\": 112024,\n      \"shield_gremlin\": 112025,\n      \"gremlin_nob\": 112037,\n      \"lagavulin\": 112026,\n      \"sentry\": 112027,\n      \"guardian\": 112046,\n      \"verify\": true,\n      \"hexaghost\": 112022,\n      \"slime_boss\": 112004,\n      \"spheric_guardian\": 112026,\n      \"centurion\": 112017,\n      \"mystic\": 112021,\n      \"taskmaster\": 112031,\n      \"book_of_stabbing\": 112024,\n      \"snake_plant\": 112033,\n      \"chosen\": 112025,\n      \"shelled_parasite\": 112014,\n      \"byrd\": 112065,\n      \"snecko\": 112037,\n      \"mugger\": 112030,\n      \"gremlin_leader\": 112020,\n      \"torch_head\": 112016,\n      \"collector\": 112022,\n      \"automaton\": 112027,\n      \"bronze_orb\": 112026,\n      \"champ\": 112018\n    },",
});
// The second pair is the exact composition with the independently reviewed
// relic additions. Removing portraits preserves every relic byte for its inverse.
export const nativeEnemyThemeComposedLayer = Object.freeze({
  beforeSha256: '2ba755b502df1a6cca9e461b4a6effd52b3905842665e794b89266f2d99a8436',
  afterSha256: 'ad7a52c5b5df717a9aa59c07bc70580d437017b95ff90a22455105b382807fd7',
});
export function preNativeEnemyThemeSource(path, source) {
  const layer = nativeEnemyThemeLayer;
  if (path !== layer.path || typeof source !== 'string') return source;
  const normalized = source.replaceAll('\r\n', '\n');
  const identity = [layer, nativeEnemyThemeComposedLayer].find(pair => hash(normalized) === pair.afterSha256);
  if (!identity) return source;
  assert.equal(normalized.split(layer.after).length, 2, 'one exact native enemy table');
  const previous = normalized.replace(layer.after, layer.before);
  assert.equal(hash(previous), identity.beforeSha256, 'complete prior theme recovered');
  return previous;
}
