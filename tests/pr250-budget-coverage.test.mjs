import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
const read=path=>readFileSync(path,'utf8').replaceAll('\r\n','\n');
const sha=text=>createHash('sha256').update(text).digest('hex');
const p=JSON.parse(read('tests/fixtures/pr250-budget-coverage.json'));
const discovered=readdirSync('tests/lua').filter(file=>file.endsWith('.lua')).map(file=>`tests/lua/${file}`).sort();

test('reward partitions retain the frozen real-victory body and cover all72 original reward targets once',()=>{
 assert.equal(p.base,'a0eedf8c8cdfb3bbab292060b3d3e81103cec9de');assert.equal(p.timeoutMilliseconds,30000);
 assert.deepEqual(p.rewardHelper,{path:'tests/lua/support/warrior75_reward_cases.lua',sha256LF:'7c6e2c485274bfc7bf06abf876116956986fccf0d70526da2ff331c68b14de07'});
 assert.equal(sha(read(p.rewardHelper.path)),p.rewardHelper.sha256LF);
 assert.deepEqual(p.rewardCounts,{common:20,uncommon:36,rare:16});
 const actualFiles=discovered.filter(path=>/^tests\/lua\/card_pool_rewards.*\.lua$/.test(path));
 assert.deepEqual(p.rewardSlices.map(row=>row.path),actualFiles);
 const seen={common:[],uncommon:[],rare:[]};
 for(const part of p.rewardSlices){
  const expected=`dofile('tests/lua/support/warrior75_reward_cases.lua')('${part.rarity}',${part.first},${part.last})`;
  const headers=[
   '-- Every original real-victory/claim/next-battle assertion remains in the frozen helper.',
   '-- All original targets, real starter victories, public claims and next-battle UID persistence.',
  ];
  assert.ok(headers.some(header=>read(part.path)===`${header}\n${expected}\n`),
   `${part.path}: the complete wrapper must execute its selector, not hide it in a long comment`);
  assert.ok(part.first<=part.last);
  seen[part.rarity].push(...Array.from({length:part.last-part.first+1},(_,i)=>part.first+i));
 }
 for(const [rarity,total]of Object.entries(p.rewardCounts))
  assert.deepEqual(seen[rarity].sort((a,b)=>a-b),Array.from({length:total},(_,i)=>i+1),`${rarity}: no omitted/duplicated identity`);
 assert.equal(Object.values(seen).flat().length,72);
});

test('copy and stolen-reward partitions reconstruct every byte of both original full suites',()=>{
 assert.equal(p.families.length,2);
 const expected=[
  {entry:'tests/lua/copied_attack.lua',tail:'tests/lua/copied_attack_reward.lua',last:33,total:34,
   bytes:11258,sha:'a3488a9491a7b5325ae702ae5825d43ced1e9053a4ad0e04b605cc9f3c652195',blob:'0be1858d4d157c0b86b3efa627da0ea73eb43e73'},
  {entry:'tests/lua/looter_rewards.lua',tail:'tests/lua/looter_rewards_invalid.lua',last:4,total:5,
   bytes:3506,sha:'5c4599f1a740c4dfb54d0658071638b6cadc02a8381bdc7cbf4793d3031d8948',blob:'d466cefc3bd4877a3996739011647aa07e92c17f'},
 ];
 for(const [index,known]of expected.entries()){
  const row=p.families[index];assert.equal(row.entry,known.entry);assert.equal(row.total,known.total);
  assert.equal(row.originalSha256LF,known.sha);assert.equal(row.originalGitBlob,known.blob);assert.equal(row.originalBytesLF,known.bytes);
  const prefix=`local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or ${known.last}\nlocal sliceRegistered,sliceExecuted=0,0\n`;
  assert.equal(row.prefix,prefix);
  const replacements=index===0?[
   {before:'    count = count + 1\n',after:'    count = count + 1\n    if count<sliceFirst or count>sliceLast then return end\n    sliceExecuted=sliceExecuted+1\n'},
   {before:'print("copied attack tests passed: " .. count)',after:'print("copied attack tests passed: " .. sliceExecuted .. " selected of " .. count)'},
  ]:[{before:'local function test(name,fn) local ok,e=pcall(fn);',after:'local function test(name,fn) sliceRegistered=sliceRegistered+1;if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end;sliceExecuted=sliceExecuted+1;local ok,e=pcall(fn);'}];
  assert.deepEqual(row.replacements,replacements);
  const footer=index===0?
   "\nassert(count==34,'all original copied-attack cases must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'all selected copied-attack cases must execute')\nprint('COPIED_ATTACK_PART '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n":
   "\nassert(sliceRegistered==5,'all original looter-reward cases must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'all selected looter-reward cases must execute')\nprint('LOOTER_REWARD_PART '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n";
  assert.equal(row.footer,footer);
  let original=read(row.entry);assert.ok(original.startsWith(prefix)&&original.endsWith(footer));
  original=original.slice(prefix.length,-footer.length);
  for(const replacement of replacements){assert.equal(original.split(replacement.after).length,2);original=original.replace(replacement.after,replacement.before);}
  assert.equal(sha(original),known.sha);const bytes=Buffer.from(original);assert.equal(bytes.length,known.bytes);
  assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),known.blob);
  assert.deepEqual(row.slices,[{path:known.entry,first:1,last:known.last},{path:known.tail,first:known.last+1,last:known.total}]);
  assert.deepEqual(discovered.filter(path=>path.startsWith(row.entry.slice(0,-4))),
   row.slices.map(part=>part.path),'the raw runner must not discover an unlisted duplicate family slice');
  const covered=[];
  for(const [partIndex,part]of row.slices.entries()){
   assert.ok(discovered.includes(part.path));
   if(partIndex)assert.equal(read(part.path),`assert(loadfile('${row.entry}'))(${part.first},${part.last})\n`);
   covered.push(...Array.from({length:part.last-part.first+1},(_,i)=>part.first+i));
  }
  assert.deepEqual(covered,Array.from({length:known.total},(_,i)=>i+1));
 }
});

test('Silent source partitions preserve the coupled reward-to-shop stream and both independent potion controls byte-for-byte',()=>{
 const row=p.silentFinal;
 const entry='tests/lua/silent_final_sources.lua',tail='tests/lua/silent_final_sources_potions.lua';
 assert.equal(row.entry,entry);assert.equal(row.total,3);assert.equal(row.originalBytesLF,2643);
 assert.equal(row.originalSha256LF,'3a8395181bae1c2618bf727e12aa8576d2287ac9a9323a81120dd3df9364aeb9');
 assert.equal(row.originalGitBlob,'239d1e1b51b478b95200dc48346f951c8a8ec1ac');
 const prefix="local sliceFirst,sliceLast=...\nsliceFirst,sliceLast=sliceFirst or 1,sliceLast or 1\nlocal sliceRegistered,sliceExecuted=0,0\nlocal function sourcePart(fn)\n sliceRegistered=sliceRegistered+1\n if sliceRegistered<sliceFirst or sliceRegistered>sliceLast then return end\n sliceExecuted=sliceExecuted+1\n fn()\nend\n";
 const replacements=[
  {before:"local run=Run.new(data,42,{character='silent',experimental=true});local expected={};local total=0\n",after:"sourcePart(function()\nlocal run=Run.new(data,42,{character='silent',experimental=true});local expected={};local total=0\n"},
  {before:"for _,spec in ipairs({{0,1,'cunning_potion'},{10,3,'ghost_in_a_jar'}})do\n",after:"end)\nfor _,spec in ipairs({{0,1,'cunning_potion'},{10,3,'ghost_in_a_jar'}})do\n sourcePart(function()\n"},
  {before:" print('ok normal initial Silent shop purchases '..spec[3])\nend\n",after:" print('ok normal initial Silent shop purchases '..spec[3])\n end)\nend\n"},
 ];
 const footer="\nassert(sliceRegistered==3,'the coupled source stream and both original potion controls must register')\nassert(sliceExecuted==sliceLast-sliceFirst+1,'every selected Silent source part must execute')\nprint('SILENT_FINAL_SOURCE_PART '..sliceFirst..' '..sliceLast..' '..sliceExecuted)\n";
 assert.equal(row.prefix,prefix);assert.deepEqual(row.replacements,replacements);assert.equal(row.footer,footer);
 let original=read(entry);assert.ok(original.startsWith(prefix)&&original.endsWith(footer));
 original=original.slice(prefix.length,-footer.length);
 for(const replacement of replacements){assert.equal(original.split(replacement.after).length,2);original=original.replace(replacement.after,replacement.before);}
 assert.equal(sha(original),row.originalSha256LF);const bytes=Buffer.from(original);assert.equal(bytes.length,2643);
 assert.equal(createHash('sha1').update(`blob ${bytes.length}\0`).update(bytes).digest('hex'),row.originalGitBlob);
 assert.deepEqual(row.slices,[{path:entry,first:1,last:1},{path:tail,first:2,last:3}]);
 assert.deepEqual(discovered.filter(path=>path.startsWith(entry.slice(0,-4))),[entry,tail]);
 assert.equal(read(tail),`assert(loadfile('${entry}'))(2,3)\n`);
 assert.deepEqual(row.slices.flatMap(part=>Array.from({length:part.last-part.first+1},(_,i)=>part.first+i)),[1,2,3]);
});
