import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {theme} from '../scripts/ui-layout.mjs';

// STS TopPanel has no exhaust chip; ExhaustPanel is a bottom-right pile above the discard pile.
test('exhaust pile left the top bar and keeps icon, count and click target clear of end turn',()=>{
 const layout=gameLayout();
 const root=name=>{const c=layout.controls.find(c=>c.name===name);assert.ok(c,name);return c;};
 const battle=root('battlePanel');
 const child=(owner,name)=>{const c=owner.children.find(c=>c.name===name);assert.ok(c,name);return c;};
 const bounds=(c,parent=[0,0])=>{const [x,y]=c.position??[0,0],[w,h]=c.size;return [x+parent[0]-w/2,y+parent[1]-h/2,x+parent[0]+w/2,y+parent[1]+h/2];};
 const icon=child(battle,'exhaustIcon'),count=child(battle,'exhaust');
 assert.deepEqual(icon.position,theme.layout.exhaustPile.position);
 assert.ok(icon.position[1]<0,'exhaust is not on the top bar');
 assert.equal(battle.children.some(c=>c.name==='exhaustLabel'),false,'ExhaustPanel draws no caption');
 const turn=theme.layout.endTurn,turnTop=turn.position[1]+turn.size[1]/2;
 const hit=child(icon,'hit'),click=bounds(hit,icon.position);
 for(const c of [icon,count,{position:click.slice(0,2),size:[0,0]}]){
  const a=c===icon||c===count?bounds(c):click;
  assert.ok(a[0]>=-600&&a[2]<=600&&a[1]>=-360&&a[3]<=360,(c.name||'hit')+' canvas');
 }
 assert.ok(click[1]>=turnTop+turn.touchGap,'exhaust hit stays touchGap above end turn');
 for(const c of [icon,count]){const a=bounds(c);assert.ok(click[0]<=a[0]&&click[2]>=a[2],'exhaust click covers icon and count');}
});
