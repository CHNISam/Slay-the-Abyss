import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const {nodes}=JSON.parse(readFileSync(new URL('./map-seed0.json',import.meta.url),'utf8'));
const byId=new Map(nodes.map(n=>[n.id,n]));
const edges=nodes.flatMap(a=>a.nextIds.map(id=>({a,b:byId.get(id)})));
test('fixed map has valid distinct adjacent-floor edges',()=>{
 assert.equal(byId.size,nodes.length);
 for(const n of nodes)assert.equal(new Set(n.nextIds).size,n.nextIds.length);
 for(const {a,b} of edges){assert.ok(b);assert.equal(b.floor,a.floor+1)}
});
test('paths do not cross between floors',()=>{
 for(const x of edges)for(const y of edges)if(x.a.floor===y.a.floor&&x.a.lane<y.a.lane)assert.ok(x.b.lane<=y.b.lane,`${x.a.id}->${x.b.id} crosses ${y.a.id}->${y.b.id}`)
});
test('every node lies on a route from entrance to terminal',()=>{
 const reachable=new Set(nodes.filter(n=>n.floor===1).map(n=>n.id));
 for(let f=1;f<=17;f++)for(const n of nodes.filter(n=>n.floor===f&&reachable.has(n.id)))for(const id of n.nextIds)reachable.add(id);
 const leadsToEnd=new Set(nodes.filter(n=>n.floor===17&&n.nextIds.length===0).map(n=>n.id));
 for(let f=16;f>=1;f--)for(const n of nodes.filter(n=>n.floor===f))if(n.nextIds.some(id=>leadsToEnd.has(id)))leadsToEnd.add(n.id);
 for(const n of nodes){assert.ok(reachable.has(n.id),`unreachable ${n.id}`);assert.ok(leadsToEnd.has(n.id),`dead end ${n.id}`)}
});
