import test from 'node:test';
import assert from 'node:assert/strict';
import {simTextProperties} from '../experiments/ui-polish-sim/sim-text.mjs';
import {relicViewControls} from '../scripts/relic-view-layout.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
test('simulator preserves production auto-size for the 40-high owned-relic name',()=>{
 const panel=relicViewControls(nativeTheme).find(c=>c.name==='relicPanel');
 const row=panel.children.find(c=>c.name==='row1');
 const name=row.children.find(c=>c.name==='name');
 assert.deepEqual(name.size,[290,40]);assert.equal(name.text.autoSize,true);
 const style=simTextProperties({...name.text,content:'余烬之心'},()=>0);
 assert.equal(style.adaptiveFontSize,true,'simulator must retain production autoSize, rather than the seed false');
 assert.equal(style.fontSize,28);assert.equal(style.minimumFontSize,28);
});
test('simulator retains explicitly fixed-size runtime card text',()=>{
 const style=simTextProperties({content:'普通攻击',fontSize:18,minFontSize:14,autoSize:false},()=>0);
 assert.equal(style.adaptiveFontSize,false);
});

test('capture retains layout sizing and explicit runtime overrides',async()=>{
 const {runLua}=await import('../scripts/test-lua.mjs');
 const r=runLua('tests/lua/ui_polish_text_style.lua');
 assert.equal(r.status,0,r.stdout+r.stderr);assert.match(r.stdout,/UI_POLISH_TEXT_STYLE_PASS/);
});
