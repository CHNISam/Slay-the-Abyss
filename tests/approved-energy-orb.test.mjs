import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {battleLayout,theme} from '../scripts/ui-layout.mjs';
import {assertNativeUiCapacity} from '../scripts/build-ui.mjs';
import {runLua} from '../scripts/test-lua.mjs';
const stage=()=>battleLayout().controls.find(c=>c.name==='stage');
const near=(a,b,message)=>assert(Math.abs(a-b)<1e-9,message);
const part=name=>stage().children.find(c=>c.name===name);
test('release energy orb keeps its Main hierarchy with the readable pile-caption clearance',()=>{
 const main=readFileSync('docs/design/ui-canvas/Main.dc.html','utf8');
 assert.match(main,/left: 92px; top: 798px; width: 132px; height: 132px/);
 // The mobile readability fix raises the unchanged orb 16 design units to
 // reserve a complete 40-unit pile-caption line below it. Original HTML stays frozen.
 const expected=[(92+132/2)/1.5-640,360-(798+132/2)/1.5+16];
 for(const name of ['energyRing','energyDisc','energyIcon','energy'])for(let axis=0;axis<2;axis++)near(part(name).position[axis],expected[axis],name+' readable center');
 // Release HUD revision 2f1f141 shell geometry and material remain intact.
 assert.deepEqual(part('energyRing').size,[100,100]);
 assert.deepEqual(part('energyDisc').size,[96,96]);
 assert.deepEqual(part('energyIcon').size,[100,100]);
 assert.deepEqual(part('energy').size,[100,100]);
 assert.equal(part('energyRing').colour,'#8A6A40');
 assert.equal(part('energyDisc').colour,'#2A1C12');
 const face=part('energyIcon').children.find(c=>c.name==='face');
 assert.deepEqual(face.position,[0,0]);
 assert.deepEqual(face.size,[88,88]);
 assert.equal(face.image,theme.image.disc);
 assert.equal(face.colour,'#B8701E');
 near(face.opacity,192/255,'release face alpha survives native colour splitting');
 const light=part('energyIcon').children.find(c=>c.name==='light');
 assert.deepEqual(light.position,[0,0]);
 assert.deepEqual(light.size,[88,88]);
 assert.equal(light.image,theme.image.discSoft);
 assert.equal(light.colour,'#FFE9B8');
 near(light.opacity,96/255,'release light alpha');
 assertNativeUiCapacity(battleLayout());
});
test('energy uses the official element picture and centered white digits with same-size drop shadow',()=>{
 const icon=part('energyIcon'),number=part('energy');
 const core=icon.children.find(c=>c.name==='core');
 assert.equal(core.image,theme.icon.energy.id,'later README requires official element material');
 assert.equal(icon.children.some(c=>c.image===theme.image.diamond),false,'no replacement invented crystal geometry');
 assert.equal(number.text.colour,'#FFF8EC');
 assert.deepEqual(core.position,[0,0]);
 assert.deepEqual(core.size,[40,40],'small elemental watermark leaves the digits dominant');
 assert.equal(core.colour,'#F6D38E');
 near(core.opacity,56/255,'release watermark alpha');
 const main=readFileSync('docs/design/ui-canvas/Main.dc.html','utf8');
 assert.match(main,/place-items: center; font-size: 44px; font-weight: 700; color: #FFF8EC/,'historical Main source typography remains available for comparison');
 // 2f1f141 supersedes the historical 44/1.5 typography with native font 40.
 // nativeFontSize rounds native fields; it does not rescale them as CSS pixels.
 assert.equal(number.text.fontSize,40);
 assert.equal(number.text.autoSize,true);
 assert.equal(number.text.minFontSize,40,'energy digits must not auto-shrink back to the old minimum');
 assert.equal(number.text.align,'centre');
 assert.equal(number.text.valign,'middle');
 const shadow=icon.children.find(c=>c.name==='valueShadow');
 assert(shadow,'source dark numeric shadow stays within the existing container');
 assert.deepEqual(shadow.size,number.size);
 assert.equal(shadow.text.fontSize,number.text.fontSize);
 assert.equal(shadow.text.colour,'#3A1E06');
 near(shadow.position[0],0);near(shadow.position[1],-2/1.5);
});
test('enlarged energy orb stays in the safe area and clear of the draw pile hit area',()=>{
 const ring=part('energyRing'),draw=part('drawIcon');
 const hit=draw.children.find(c=>c.name==='hit');
 const [x,y]=ring.position,[w,h]=ring.size;
 assert(x-w/2>=-600&&x+w/2<=600&&y-h/2>=-340&&y+h/2<=340,'1280x720 safe area');
 const drawHitTop=draw.position[1]+(hit.position?.[1]??0)+hit.size[1]/2;
 assert(y-h/2-drawHitTop>=2-1e-9,'at least two native units above draw hit area');
});
test('real battle energy readout keeps zero overcharge spending and reward visibility intact',()=>{
 const result=runLua('tests/lua/approved_energy_orb.lua');
 assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/APPROVED_ENERGY_ORB_PASS/);
});
