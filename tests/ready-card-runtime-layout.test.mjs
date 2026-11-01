import test from 'node:test';import assert from 'node:assert/strict';
import {gameLayout}from'../scripts/game-ui-layout.mjs';import{deckCardTemplate}from'../scripts/deck-ui-layout.mjs';
import{assertNativeUiCapacity}from'../scripts/build-ui.mjs';
import{assertReadyCardGameHosts,expectedReadyCardGameHosts,expectedReadyCardChoiceHosts}from'./helpers/ready-card-host-contract.mjs';
import{attachReadyCardHosts,readyArtTemplates,bindReadyCardPresentation}from'../scripts/art/ready-card-runtime.mjs';
test('every actual card face and recyclable deck template gets only an empty bounded-runtime holder',()=>{
 const game=gameLayout(),deck=deckCardTemplate();
 const hosts=attachReadyCardHosts(game);
 assert.equal(expectedReadyCardGameHosts.length,38+12+10);
 assert.equal(expectedReadyCardChoiceHosts.length,10);
 assert.deepEqual([...hosts].sort(),expectedReadyCardGameHosts.map(path=>path.replace('/stage/','/')).sort());
 assertReadyCardGameHosts(game,{staged:false});
 assert.equal(attachReadyCardHosts(deck).length,1);
 assert(hosts.includes('SlayTheAbyss/nodePanel/pickerView/forgeGrid/card12'));
 function verify(n){if(n.name==='artSamples'){assert.deepEqual(n.children,[]);assert.equal(n.visible,false);}for(const c of n.children??n.controls??[])verify(c);}
 verify(game);verify(deck);assertNativeUiCapacity(game);assertNativeUiCapacity(deck);
 assert.throws(()=>attachReadyCardHosts(game),/combine/);
 assert.equal(readyArtTemplates().length,2);
});
test('only frozen reviewed IDs get runtime art; rules and dynamic text stay independent',()=>{
 const cards={armaments:{name:'整备武装',textTemplate:'原效果'},cleave:{},heavy_blade:{},strike:{name:'普通攻击'}};
 const registry=bindReadyCardPresentation(cards);assert.equal(cards.armaments.nativeArt.runtime,true);
 assert.equal(cards.armaments.textTemplate,'原效果');assert.equal(cards.strike.nativeArt,undefined);
 assert.deepEqual(Object.keys(registry.assets),['armaments','cleave','heavy_blade']);
});
test('candidate binding needs two real positive template indices and records the bounded runtime',async()=>{
 const m=await import('../scripts/art/ready-card-runtime.mjs');
 assert.equal(typeof m.bindReadyArtTemplates,'function');
 const fs=await import('node:fs'),os=await import('node:os'),path=await import('node:path');
 const dir=fs.mkdtempSync(path.join(os.tmpdir(),'ready-art-binding-'));
 try{
  assert.throws(()=>m.bindReadyArtTemplates(dir,{image:100001}),/template/);
  m.bindReadyArtTemplates(dir,{image:{templateIndex:1101},group:{templateIndex:1102}});
  const source=fs.readFileSync(path.join(dir,m.readyArtModule),'utf8');
  assert.match(source,/imageTemplateIndex=1101/);assert.match(source,/containerTemplateIndex=1102/);
  assert.equal(m.readyArtRuntimeInventory().maxLivePools,10);
  assert.equal(m.readyArtRuntimeInventory().peakDynamicControls,27020);
 }finally{fs.rmSync(dir,{recursive:true,force:true});}
});

test('each combat-choice holder identity, empty payload and dormant state is required independently',()=>{
 const game=gameLayout();attachReadyCardHosts(game);
 const choice=game.controls.find(node=>node.name==='choicePanel');
 assert(choice);
 for(let slot=1;slot<=10;slot++){
  const face=choice.children.find(node=>node.name===`card${slot}`).children.find(node=>node.name==='face');
  const holder=face.children.find(node=>node.name==='artSamples');
  assert(holder,`choice slot ${slot}`);
  assert(expectedReadyCardChoiceHosts.includes(`SlayTheAbyss/stage/choicePanel/card${slot}/face`));
  holder.name='missingHolder';assert.throws(()=>assertReadyCardGameHosts(game,{staged:false}));holder.name='artSamples';
  face.name='wrongFace';assert.throws(()=>assertReadyCardGameHosts(game,{staged:false}));face.name='face';
  holder.children=[{name:'unexpectedStaticImage',kind:'image'}];
  assert.throws(()=>assertReadyCardGameHosts(game,{staged:false}),/empty/);holder.children=[];
  holder.visible=true;assert.throws(()=>assertReadyCardGameHosts(game,{staged:false}),/dormant/);holder.visible=false;
 }
 assertReadyCardGameHosts(game,{staged:false});
});
