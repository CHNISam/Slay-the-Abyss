import test from 'node:test';
import assert from 'node:assert/strict';
import {mapLayout,mapGeometry,loadMapTheme} from '../scripts/map-ui-layout.mjs';
const rows=[['combat','普通战斗'],['elite','精英'],['event','事件'],['shop','商店'],['camp','营地'],['treasure','宝箱'],['boss','首领']];
const theme=loadMapTheme();
function legend(source=theme){
 const controls=mapLayout(source).controls.find(c=>c.name==='stage').children[0].children.flatMap(g=>g.children);
 const panel=controls.find(c=>c.name==='typeLegend');
 assert(panel,'map must explain all seven node types');
 return panel;
}
test('approved map type legend retains seven Chinese meanings and the same official node icons',()=>{
 const panel=legend();
 assert.equal(panel.children.find(c=>c.name==='title').text.content,'节点类型');
 for(const [kind,label] of rows){
  assert.equal(panel.children.find(c=>c.name===kind+'Icon').image,theme.icon.node[kind]);
  const text=panel.children.find(c=>c.name===kind+'Label');
  assert.equal(text.text.content,label);assert(text.size[1]>=40);assert(text.text.fontSize>=theme.font.minimum);
 }
 assert.equal(panel.children.filter(c=>c.kind==='text').length,8,'no retired state explanations');
});
test('type legend stays outside routes, phone safe margins and resource/menu bars',()=>{
 const panel=legend(),g=mapGeometry(theme),[x,y]=panel.position,[w,h]=panel.size;
 assert(x-w/2>g.viewport.right,'legend must not cover the scroll/hit viewport');
 assert(x+w/2<=640-theme.canvas.safe.x);assert(y-h/2>=-360+theme.canvas.safe.y);
 assert(y+h/2<260,'legend must remain below resource/menu bars');
 for(const c of panel.children){
  assert(Math.abs(c.position[0])+c.size[0]/2<=w/2,c.name);
  assert(Math.abs(c.position[1])+c.size[1]/2<=h/2,c.name);
  assert.notEqual(c.kind,'cursorArea','legend must not intercept map gestures');
 }
});
test('legend follows shared map tokens and node icons without reviving navigation controls',()=>{
 const altered=structuredClone(theme);
 altered.layout.map.presentation.typeLegend.position=[520,-130];altered.icon.node.elite=100128;
 const panel=legend(altered);assert.deepEqual(panel.position,[520,-130]);
 assert.equal(panel.children.find(c=>c.name==='eliteIcon').image,100128);
 const controls=mapLayout(altered).controls[1].children[0].children.flatMap(g=>g.children);
 for(const name of ['previous','focus','next'])assert.equal(controls.find(c=>c.name===name).visible,false);
});
