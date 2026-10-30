// Test-only outer normalization of the reviewed M4 deck controls. Old full-source
// witnesses and all runtime fixtures remain unchanged; unknown bytes pass through.
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {restoreExactFixtureHunks} from './exact-fixture-hunks.mjs';
import {deepFreezeSourceProof} from './pure-source-projection-cache.mjs';
const bytes=readFileSync(new URL('../fixtures/deck-browse-source-layer.json',import.meta.url),'utf8').replaceAll('\r\n','\n');
assert.equal(createHash('sha256').update(bytes).digest('hex'),'e2088cf3a33fcd27e23d97b9996cfc97c75e5da4ec5933c34507cc06dec37bf6','complete M4 deck-browse source proof');
export const deckBrowseSourceLayer=deepFreezeSourceProof(JSON.parse(bytes));
assert.equal(deckBrowseSourceLayer.baseCommit,'ef7b3e80093dd737be5496627250269532da001c');
assert.equal(deckBrowseSourceLayer.reviewedHead,'c961ad442b9677741acf04452e84f0e8bcc2d760');
assert.deepEqual(Object.keys(deckBrowseSourceLayer.files),["data/presentation/ui_theme.json", "scripts/character-ui-layout.mjs", "scripts/deck-ui-layout.mjs", "src/lua/abyss_character_select.lua", "src/lua/abyss_character_select_view.lua", "src/lua/abyss_deck_ui.lua", "src/lua/abyss_game_ui.lua"]);
export function preDeckBrowseSource(path,source){
 const proof=deckBrowseSourceLayer.files[path];
 return proof?restoreExactFixtureHunks(proof,path,source):source;
}
