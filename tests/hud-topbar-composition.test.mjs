import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';

test('final shared HUD leaves the exhaust icon, count and click target unobstructed',()=>{
 const layout=gameLayout();
 const root=name=>{const c=layout.controls.find(c=>c.name===name);assert.ok(c,name);return c;};
 const battle=root('battlePanel');
 const child=(owner,name)=>{const c=owner.children.find(c=>c.name===name);assert.ok(c,name);return c;};
 const bounds=(c,parent=[0,0])=>{const [x,y]=c.position??[0,0],[w,h]=c.size;return [x+parent[0]-w/2,y+parent[1]-h/2,x+parent[0]+w/2,y+parent[1]+h/2];};
 const icon=child(battle,'exhaustIcon'),count=child(battle,'exhaust');
 const targets=[icon,count];
 const obstacles=[child(battle,'title'),...Array.from({length:5},(_,i)=>child(i<3?battle:child(battle,'potionHelp'),'potion'+(i+1))),
  child(root('relicEntry'),'open'),child(root('deckEntry'),'open'),child(root('exitEntry'),'open'),child(root('relicBar'),'tray')];
 const clear=(a,b)=>a[2]<=b[0]||b[2]<=a[0]||a[3]<=b[1]||b[3]<=a[1];
 for(const c of targets){
  const a=bounds(c);assert.ok(a[0]>=-600&&a[2]<=600&&a[1]>=-360&&a[3]<=360,c.name+' canvas');
  for(const obstacle of obstacles)assert.ok(clear(a,bounds(obstacle)),`${c.name} overlaps shared ${obstacle.name}`);
 }
 const hit=child(icon,'hit'),click=bounds(hit,icon.position);
 for(const obstacle of obstacles)assert.ok(clear(click,bounds(obstacle)),`exhaust hit overlaps shared ${obstacle.name}`);
 for(const c of targets){const a=bounds(c);assert.ok(click[0]<=a[0]&&click[2]>=a[2],'original exhaust click covers icon and count');}
});
