import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {buildLuaData} from '../scripts/build-lua-data.mjs';
import {runLua} from '../scripts/test-lua.mjs';
import {historicalPresentationFixtures} from './helpers/historical-presentation-runner.mjs';
import {phaseFourCardCounts as proof,prePhaseFourCardCountSource as project} from './helpers/phase-four-card-count-inverse.mjs';
const hash=s=>createHash('sha256').update(s).digest('hex');
const current=readFileSync(proof.path,'utf8').replaceAll('\r\n','\n');

test('only two positioned additive Bell counts recover the unchanged complete frozen render witness',()=>{
 assert.equal(hash(current),proof.afterSha256);assert.equal(proof.hunks.length,2);
 assert.equal(hash(project(proof.path,current)),proof.beforeSha256);
 assert.equal(project(proof.path,current.replaceAll('\n','\r\n')),project(proof.path,current));
 assert.equal(project(proof.path,project(proof.path,current)),project(proof.path,current));
 const mutants=[current+'\n-- drift\n',current.slice(1),current.replace('for _,card in ipairs(data.cards.cards)do','for _,card in ipairs({})do')];
 for(const hunk of proof.hunks){
  const lines=current.split('\n');
  for(const replacement of [[],[hunk.after,hunk.after],[hunk.before],['  -- altered count']]){
   const changed=[...lines];changed.splice(hunk.at,1,...replacement);mutants.push(changed.join('\n'));
  }
  const moved=[...lines];moved.splice(hunk.at,1);moved.push(hunk.after);mutants.push(moved.join('\n'));
 }
 for(const mutant of mutants){assert.notEqual(mutant,current);assert.equal(project(proof.path,mutant),mutant,'unknown bytes remain exposed to frozen guards');}
 assert.equal(project('other.lua',current),current);
});

test('each current prepared class really contains one Bell curse, without changing its original regular pools',()=>{
 buildLuaData();writeFileSync('build/lua/current_bell_matrix.lua',`
local prepared=dofile('tests/lua/support/phase_four_presentation_data.lua')
for _,role in ipairs({'ironclad','silent','defect','watcher'})do
 local d=prepared(role);local bell=0
 for _,card in ipairs(d.cards.cards)do if card.id=='curse_of_the_bell'then
  assert(card.sourceId=='CurseOfTheBell' and card.type=='curse' and card.cost==-2)
  assert(require('abyss_card_capability').isImplemented(card));bell=bell+1
 end end
 assert(bell==1,role..' must add exactly one Bell to the real complete matrix')
end
print('CURRENT_BELL_MATRIX_FOUR_CLASSES_PASS')
`);
 const result=runLua('build/lua/current_bell_matrix.lua');assert.equal(result.status,0,result.stdout+result.stderr);
 assert.match(result.stdout,/CURRENT_BELL_MATRIX_FOUR_CLASSES_PASS/);
});

for(const [i,role,variants]of [[1,'ironclad',162],[2,'silent',182],[3,'defect',182],[4,'watcher',202]]){
 test(`current ${role} real BattleUI and DeckUI retain every original card plus both Bell variants`,()=>{
  const file=i===1?proof.path:`tests/lua/phase_four_presentation_render_slice_${i}.lua`;
  assert.ok(!historicalPresentationFixtures.includes(file),'current matrix must never run against historical data');
  const result=runLua(file);assert.equal(result.status,0,result.stdout+result.stderr);
  assert.match(result.stdout,new RegExp(`phase_four_presentation_render: 1 passed; ${variants} real card render variants`));
 });
}
