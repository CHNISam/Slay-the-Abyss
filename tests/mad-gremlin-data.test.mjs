import test from 'node:test';
import assert from 'node:assert/strict';
import { loadContent, validateContent } from '../scripts/validate-data.mjs';
const enemy = data => data.enemies.enemies.find(e => e.id === 'mad_gremlin');
const policy = {kind:'mad_gremlin', attackIntent:'mad_gremlin_1', rollRange:100, angryStacks:1};
test('playable Mad Gremlin has A0 HP, passive Angry and only attack4', () => {
 const data=loadContent('data'),e=enemy(data);
 assert.deepEqual(e.hpRange,{min:20,max:24});assert.deepEqual(e.ai,policy);
 assert.deepEqual(e.intents,[{id:'mad_gremlin_1',kind:'attack',effects:[{op:'damage',value:4}]}]);
 const status=data.statuses.statuses.find(s=>s.id==='angry');assert.equal(status.kind,'buff');assert.equal(status.stack,'intensity');assert.equal(status.decay,'none');
 assert.deepEqual(validateContent(data),[]);
});
test('valid Mad Gremlin policy and Angry status enter runtime schema',()=>{
 const data=loadContent('data');enemy(data).ai={...policy};
 if(!data.statuses.statuses.some(s=>s.id==='angry'))data.statuses.statuses.push({id:'angry',name:'Test',kind:'buff',stack:'intensity',decay:'none',description:'Test'});
 assert.deepEqual(validateContent(data),[]);
});
for(const [name,key,value] of [
 ['missing passive','angryStacks',undefined],['zero passive','angryStacks',0],['negative passive','angryStacks',-1],['fractional passive','angryStacks',1.5],['overflow passive','angryStacks',2147483648],
 ['missing roll','rollRange',undefined],['zero roll','rollRange',0],['too large roll','rollRange',65537],['unknown attack','attackIntent','no_such_intent'],['unknown field','guess',1],
])test(`Mad Gremlin rejects ${name}`,()=>{
 const data=loadContent('data');enemy(data).ai={...policy,[key]:value};if(value===undefined)delete enemy(data).ai[key];
 assert.ok(validateContent(data).some(e=>e.includes(key)));
});
test('Mad Gremlin requires an Angry status definition',()=>{
 const data=loadContent('data');enemy(data).ai={...policy};data.statuses.statuses=data.statuses.statuses.filter(s=>s.id!=='angry');
 assert.ok(validateContent(data).some(e=>e.includes('angry')));
});

test('Angry uses an approved picture mapping and the complete theme validates', async()=>{
 const {readFileSync}=await import('node:fs');
 const {validateTheme}=await import('../scripts/build-ui-theme.mjs');
 const theme=JSON.parse(readFileSync('data/presentation/ui_theme.json','utf8'));
 assert.equal(theme.icon.status.angry,103047);
 assert.deepEqual(validateTheme(theme,loadContent('data')),[]);
});
