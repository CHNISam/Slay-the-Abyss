// Test-only inverse of #439's readable text sizes. Frozen actor/hero digests
// still compare every other field; never erase unknown controls or geometry.
import assert from 'node:assert/strict';
export function preReadableUnitTypography(unit,{hero=false}={}) {
 const previous=structuredClone(unit);
 const revert=(controls,name,before,after)=>{
  const matches=controls.filter(c=>c.name===name);assert.equal(matches.length,1,'unique reviewed text '+name);
  const text=matches[0].text;assert(text,'reviewed text '+name);
  assert.deepEqual([text.fontSize,text.minFontSize],[after,after],'exact readable typography '+name);
  text.fontSize=before;text.minFontSize=14;
 };
 for(const [name,before,after]of [['name',16,22],['hp',14,20],['damagePreview',16,22],['block',18,24],['floating',22,28]])
  revert(previous.children,name,before,after);
 if(hero){
  const rows=previous.children.filter(c=>c.name==='statusRow');assert.equal(rows.length,1);
  for(let i=1;i<=10;i++)revert(rows[0].children,'count'+i,14,20);
 }else{
  revert(previous.children,'intent',15,15);revert(previous.children,'intentLabel',16,22);
 }
 return previous;
}
