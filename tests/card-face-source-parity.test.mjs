import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {cardFaceChildren} from '../scripts/card-face.mjs';
import {nativeTheme} from '../scripts/native-ui-theme.mjs';
const source=readFileSync('docs/design/ui-canvas/Card.dc.html','utf8');
test('approved Card header centres the title and keeps the thirty-pixel cost disc separate from native text height',()=>{
  assert.match(source,/left: 60px; right: 60px; top: 12px; height: 48px/);
  assert.match(source,/left: -10px; top: -10px; width: 60px; height: 60px/);
  for(const context of ['battle','deck','node']){
    const parts=Object.fromEntries(cardFaceChildren(nativeTheme,context).map(c=>[c.name,c]));
    assert.deepEqual(parts.name.position,[0,86],context+' source title centre');
    assert.deepEqual(parts.costCore.position,[-64,94]);
    assert.deepEqual(parts.costCore.size,[33,33]);
    assert.deepEqual(parts.costDisc.size,[30,30]);
    assert(parts.cost.size[1]>=40,'transparent native cost text remains compatible');
    assert(parts.name.size[0]>=98&&parts.name.size[1]>=40,'full seven-character name at native 14px floor');
  }
});

const raidenPath=source.match(/raiden: '([^']+)'/)[1];
// Exact absolute vertices of Card.dc.html's path, including relative h segments.
const sourcePoints=[[14,1],[4,13.5],[10.2,13.5],[8.5,23],[20,9.5],[13.6,9.5]].map(([x,y])=>[(x-12)*.375,(12-y)*.375]);
const area=points=>Math.abs(points.reduce((sum,p,i)=>{const q=points[(i+1)%points.length];return sum+p[0]*q[1]-q[0]*p[1];},0)/2);
const transform=(p,c)=>{const a=(c.rotation??0)*Math.PI/180,[sx,sy]=c.scale??[1,1],[x,y]=c.position??[0,0];return[x+Math.cos(a)*p[0]*sx-Math.sin(a)*p[1]*sy,y+Math.sin(a)*p[0]*sx+Math.cos(a)*p[1]*sy];};
test('native Raiden emblem triangulates the approved six-vertex path without changing its outline or scale',()=>{
  assert.equal(raidenPath,'M14 1L4 13.5h6.2L8.5 23L20 9.5h-6.4Z');
  const face=cardFaceChildren(nativeTheme,'battle');
  const mark=face.find(c=>c.name==='roleMark'),rd=mark.children.find(c=>c.name==='RD');
  const triangles=[];
  function visit(c,parents=[]){
    if(c.kind==='image'){
      assert.equal(c.image,100003);
      const [w,h]=c.size;
      triangles.push([[0,h/2],[-w/2,-h/2],[w/2,-h/2]].map(p=>[c,...parents].reduce(transform,p)));
    }
    for(const child of c.children??[])visit(child,[c,...parents]);
  }
  for(const child of rd.children)visit(child);
  assert.equal(triangles.length,4,'concave source hexagon has four exact triangles, not two invented tips');
  for(const p of triangles.flat())assert(sourcePoints.some(q=>Math.hypot(q[0]-p[0],q[1]-p[1])<1e-10),'native vertex must match an approved vertex');
  assert(Math.abs(triangles.reduce((sum,t)=>sum+area(t),0)-area(sourcePoints))<1e-10,'no missing area or overlap');
  const pointKey=p=>p.map(n=>n.toFixed(8)).join(',');
  const edgeKey=(a,b)=>[pointKey(a),pointKey(b)].sort().join('|');
  const counts=new Map();
  for(const t of triangles)for(let i=0;i<3;i++){const key=edgeKey(t[i],t[(i+1)%3]);counts.set(key,(counts.get(key)??0)+1);}
  assert.deepEqual([...counts].filter(([,n])=>n===1).map(([key])=>key).sort(),sourcePoints.map((p,i)=>edgeKey(p,sourcePoints[(i+1)%6])).sort(),'shared internal edges cancel to exactly the approved six boundary edges');
  assert.deepEqual(mark.position,[0,-104],'source emblem centre stays on the bottom edge');
});
