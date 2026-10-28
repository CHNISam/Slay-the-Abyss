import test from 'node:test';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdtempSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {cardFaceChildren} from '../scripts/card-face.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
import {toLua,luaString} from '../scripts/build-lua-data.mjs';
import {buildUiTheme} from '../scripts/build-ui-theme.mjs';
import {runLua} from '../scripts/test-lua.mjs';

// Only the real CardSkin/Display modules run; unrelated combat/host fixtures do not load.
export function skinPreviewStates({upgradedDefend=false}={}){
 const directory=mkdtempSync(join(tmpdir(),'card-source-parity-'));
 try{
  buildUiTheme(undefined,undefined,join(directory,'abyss_theme.lua'));
  const defend=JSON.parse(readFileSync('data/cards.json','utf8')).cards.find(c=>c.id==='defend');
  const rendered=spawnSync(process.env.ABYSS_PYTHON||'python',['tools/render_traveler_cards.py','data/cards.json','data/presentation/traveler.zh-CN.json'],{encoding:'utf8',timeout:15000});
  assert.equal(rendered.status,0,rendered.stderr);
  const display=JSON.parse(rendered.stdout).cards.find(c=>c.id==='defend');
  const face=cardFaceChildren(nativeTheme,'battle');
  const script=`package.path=${luaString(directory+'/?.lua;src/lua/?.lua;')}..package.path
CARD_SKIN_UPGRADED=${upgradedDefend?'true':'false'}
local function control(spec)
 local c={children={},visible=spec.visible~=false,text=spec.text and spec.text.content or '',fontSize=spec.text and spec.text.fontSize}
 function c:GetChild(name)return assert(self.children[name],name)end
 function c:SetVisible(value)self.visible=value end
 function c:SetLocalScale(x,y,z)self.localScaleX,self.localScaleY=x,y end
 function c:SetSizeDelta(w,h)self.size={w,h};self.sizeDeltaX,self.sizeDeltaY=w,h end
 function c:SetAnchoredPosition(x,y)self.x,self.y=x,y end
 for _,child in ipairs(spec.children or {})do c.children[child.name]=control(child)end
 return c
end
local F={control=control,Theme=require('abyss_theme'),Presentation={defend=${toLua(display)}},Data={cards={cards={${toLua(defend)}}}},Viewport={apply=function(root)return root end},Layout={{name='battlePanel',children={{name='card1',children=${toLua(face)}}}}}}
local original=dofile
dofile=function(path)if path=='tests/lua/support/game_ui_fixture.lua' then return F end return original(path)end
original('tests/lua/card_skin.lua')
`;
  const path=join(directory,'preview.lua');writeFileSync(path,script);
  const result=runLua(path,{timeout:10000});assert.equal(result.status,0,result.stderr);
  return result.stdout.split('\n').filter(s=>s.startsWith('SKIN_PREVIEW ')).map(s=>JSON.parse(s.slice(13)));
 }finally{rmSync(directory,{recursive:true,force:true});}
}

test('preview Defend is assembled from its real one-energy definition, never a fabricated absent-cost case',()=>{
 const states=skinPreviewStates(),fifth=states[4].children;
 assert.equal(states.length,6);
 assert.equal(fifth.name.text,'防御');
 assert.equal(fifth.cost.text,'1');
 for(const part of ['costCore','costDisc','cost'])assert.equal(fifth[part].visible,true,part);
 assert.equal(fifth.label.text,'获得 5 点格挡。');
});
