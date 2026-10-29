import {preBattleRefactorSource} from './helpers/battle-refactor-projection.mjs';
import {postApprovedCardDragClickSource} from './helpers/task76-drag-click-inverse.mjs';
import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {runLua} from '../scripts/test-lua.mjs';
import {p0Presentation,preAcceptedPresentation,preCardDragClickSource} from './helpers/p0-presentation-inverse.mjs';
import {acceptedPresentationSource} from './helpers/presentation-m3-integration.mjs';
import {preRetirementSource} from './helpers/presentation-announcement-retirement.mjs';
import {preApprovedUiSource} from './helpers/approved-ui-inverse.mjs';
const path='src/lua/abyss_battle_ui.lua';
const source=postApprovedCardDragClickSource(preBattleRefactorSource(path,readFileSync(path,'utf8')));
const hash=value=>createHash('sha256').update(value).digest('hex');

test('real drag release preserves independent Click-only actions and original card ownership',()=>{
  const result=runLua('tests/lua/battle_ui_drag_click_compatibility.lua',{timeout:30000});
  assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,/LUA_DRAG_CLICK_COMPATIBILITY 15 passed; 0 failed/);
  assert.equal([...result.stdout.matchAll(/^PASS /gm)].length,15);
});

test('drag-only historical inverse preserves complete old identities and rejects other drift',()=>{
  const original=preCardDragClickSource(path,source);
  assert.equal(hash(source),'067b6761d5f02477ec2aeb848b2a00eb2b4191517d30096f7cb8dc84e3f0b382');
  assert.equal(hash(original),'a1d68a1fcba74fff54fb22cb4641cd400e4c76e2d3a7e22d69e352efeb8e7d91');
  assert.equal(hash(preApprovedUiSource(path,original)),p0Presentation.files[path].afterSha256);
  assert.equal(preApprovedUiSource(path,source),preApprovedUiSource(path,original));
  assert.equal(preCardDragClickSource(path,source.replaceAll('\n','\r\n')),original);
  assert.equal(preCardDragClickSource(path,original),original);
  assert.equal(hash(preAcceptedPresentation(path,preApprovedUiSource(path,source))),p0Presentation.files[path].beforeSha256);
  assert.equal(preRetirementSource(path,source),preRetirementSource(path,original));
  const popupPath='src/lua/abyss_battle_potion_popup.lua';
  const popup=readFileSync(popupPath,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(popup),'c530888e8afe4c98120fa51b459b1724c7be93fa76f48334ac368031806e08bd');
  assert.equal(hash(preCardDragClickSource(popupPath,popup)),'d50f03654abd678719f610bce920f67c5b7bc45656103231fae04f3c3761ceba');
  assert.equal(preApprovedUiSource(popupPath,popup),null,'only the complete approved added popup disappears in historical replay');
  for(const mutant of [popup+'\n-- drift\n',
    popup.replace('            if actions.pointerClick and not actions.pointerClick(event)then return false end\n',''),
    popup.replace('                    if actions.pointerDown then actions.pointerDown(event)end\n','')]){
    assert.notEqual(mutant,popup);
    assert.throws(()=>preApprovedUiSource(popupPath,mutant),/unreviewed integrated/);
  }
  const fixturePath='tests/lua/support/battle_ui_cases.lua';
  const fixture=readFileSync(fixturePath,'utf8').replaceAll('\r\n','\n');
  assert.equal(hash(fixture),'6adf9566320c60e8b68fb8854ccbf9dffb0eb34f7510d5a32309d4a3461d7590');
  const originalFixture=preCardDragClickSource(fixturePath,fixture);
  assert.equal(hash(originalFixture),'874ad3cf102493953104fe3d556e6839b5599a249d37679b5a2fad862517375d');
  assert.equal(preApprovedUiSource(fixturePath,fixture),preApprovedUiSource(fixturePath,originalFixture));
  const namedGhost='    event("enemy1","click",stage.children.enemy1.x,stage.children.enemy1.y,0) -- queued same-origin release click\n';
  for(const mutant of [fixture+'\n-- drift\n',fixture.replace(namedGhost,''),fixture.replace(namedGhost,namedGhost+namedGhost)]){
    assert.notEqual(mutant,fixture);
    assert.throws(()=>preApprovedUiSource(fixturePath,mutant),/unreviewed integrated/);
  }
  const token="        self.suppressClick,self.selected = g,action ~= 'cancel' and g.uid or nil\n";
  const mutants=[source+'\n-- unrelated drift\n',source.replace(token,token+token),
    source.replace(token,token.replace(' = g,',' = true,')),
    source.replace('        self.suppressClick = nil\n',''),
    source.replace('        if touch ~= nil and touch == releasedDragTouch then return true end\n',''),
    source.replace('then return self:openPotionMenu(slot) end','then return self:usePotion(slot) end')];
  for(const mutant of mutants){
    assert.notEqual(mutant,source);
    assert.throws(()=>preAcceptedPresentation(path,preApprovedUiSource(path,mutant)),/unreviewed integrated/);
    assert.throws(()=>preApprovedUiSource(path,mutant),/unreviewed integrated/);
    assert.throws(()=>acceptedPresentationSource(path,mutant),/unreviewed integrated/);
  }
});
