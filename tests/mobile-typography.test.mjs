import test from 'node:test';
import assert from 'node:assert/strict';
import {gameLayout} from '../scripts/game-ui-layout.mjs';
import {nativeTheme as theme} from '../scripts/native-ui-theme.mjs';
const child=(c,n)=>{const v=(c.children??c.controls).find(x=>x.name===n);assert.ok(v,n);return v;};
const tree=()=>gameLayout();
const states=['normal','hover','pressed','disabled'];
function budget(control,copy){
 const f=control.text.fontSize;
 const width=[...copy].reduce((n,c)=>n+(c.codePointAt(0)>255?1:.6)*f,0);
 assert.ok(control.size[0]>=width+4,`${control.name} ${copy}: needs ${width+4}, has ${control.size[0]}`);
 assert.ok(control.size[1]>=40,`${control.name}: full native line`);
 assert.equal(control.text.minFontSize,f,`${control.name}: cannot autoshrink`);
}
test('default resource values stay large and fit seven-digit health and five-digit gold',()=>{
 const t=tree(), battle=child(t,'battlePanel'),map=child(child(t,'mapPanel'),'resources'),node=child(t,'nodePanel');
 for(const [c,copy]of [[child(battle,'player'),'999/999'],[child(battle,'piles'),'99999'],[child(battle,'exhaust'),'999'],[child(battle,'floor'),'17'],[child(map,'hp'),'999/999'],[child(map,'gold'),'99999'],[child(node,'hp'),'999/999'],[child(node,'gold'),'99999'],[child(node,'deck'),'999']]){
  assert.ok(c.text.fontSize>=28,c.name+' default HUD size');budget(c,copy);
 }
});
test('every deck and relic entry count has a complete large native line',()=>{
 const t=tree();for(const name of ['deckEntry','relicEntry'])for(const state of states){const c=child(child(child(child(t,name),'open'),'hit'),state);const count=child(c,'count');assert.ok(count.text.fontSize>=22,name+' count');budget(count,'999');}
 const slot=child(child(t,'relicBar'),'slot12');budget(child(slot,'more'),'+99');
});
test('normal menu reading and warnings use larger text without fallback shrink',()=>{
 const t=tree(),exit=child(t,'exitPanel');
 for(const name of ['title','message','status']){const c=child(exit,name);assert.ok(c.text.fontSize>=20,name);assert.equal(c.text.fontSize,c.text.minFontSize);}
 const message=child(exit,'message');assert.ok(message.text.fontSize>=24);assert.ok(message.size[1]>=80,'two full native lines');
 assert.ok(child(exit,'status').size[1]>=40);
 for(const panel of ['exitPanel','runMenu'])for(const button of (panel==='exitPanel'?['cancel','confirm','help']:['resume','help','map','abandon']))for(const state of states){const c=child(child(child(child(t,panel),button),'hit'),state);const label=child(c,'label');assert.ok(label.text.fontSize>=22);budget(label,label.text.content);}
});
function luminance(hex){const c=hex.match(/[a-f\d]{2}/gi).slice(0,3).map(h=>{const n=parseInt(h,16)/255;return n<=.04045?n/12.92:((n+.055)/1.055)**2.4});return c[0]*.2126+c[1]*.7152+c[2]*.0722;}
function contrast(a,b){const x=luminance(a),y=luminance(b);return(Math.max(x,y)+.05)/(Math.min(x,y)+.05);}
test('muted ordinary reading reaches 4.5 on the opaque menu surfaces',()=>{
 for(const bg of ['panel','panelRaised','panelSunken'])assert.ok(contrast(theme.color.textMuted,theme.color[bg])>=4.5,bg);
});
test('readable resource targets and utility controls do not overlap',()=>{
 const t=tree(), b=child(t,'battlePanel');
 const bounds=c=>{const[x,y]=c.position??[0,0],[w,h]=c.size;return[x-w/2,y-h/2,x+w/2,y+h/2];};
 const controls=['player','piles','floorIcon','floor','title','exhaust'].map(n=>child(b,n));
 controls.push(...['deckEntry','exitEntry'].map(n=>child(child(t,n),'open')));
 controls.push(...[1,2,3].map(n=>child(b,'potion'+n)),...[4,5].map(n=>child(child(b,'potionHelp'),'potion'+n)));
 for(let i=0;i<controls.length;i++)for(let j=i+1;j<controls.length;j++){let a=bounds(controls[i]),c=bounds(controls[j]);assert.ok(a[2]<=c[0]||c[2]<=a[0]||a[3]<=c[1]||c[3]<=a[1],`${controls[i].name} overlaps ${controls[j].name}`);}
});
test('existing full-reading surfaces enlarge body text and reserve readable line pitch',()=>{
 const t=tree(),deck=child(t,'deckPanel'),info=child(child(t,'battlePanel'),'statusInfo');
 assert.ok(child(deck,'details').text.fontSize>=24);assert.equal(child(deck,'details').text.minFontSize,child(deck,'details').text.fontSize);
 assert.ok(theme.layout.statusInfo.line>=28,'detail body needs room at 20-unit glyphs');
 assert.ok(theme.layout.potionPopup.font>=20,'potion copy is ordinary reading');
 assert.ok(theme.layout.potionPopup.line>=28);
 assert.ok(child(info,'text1').text.fontSize>=20);
});
test('real Lua host retains complete values and paged long reading with the enlarged defaults',async()=>{
 const {runLua}=await import('../scripts/test-lua.mjs');
 const r=runLua('tests/lua/mobile_typography.lua');assert.equal(r.status,0,r.stdout+r.stderr);
 assert.match(r.stdout,/MOBILE_TYPOGRAPHY_RUNTIME_PASS/);
 const snapshots=Object.fromEntries(r.stdout.split(/\r?\n/).filter(l=>l.startsWith('UI_READABILITY\t')).map(l=>{const[,name,json]=l.split('\t');return[name,JSON.parse(json)];}));
 for(const [name,path,copy]of [['mobile-map','/mapPanel/resources/hp','999/999'],['mobile-map','/mapPanel/resources/gold','99999'],['mobile-battle','/battlePanel/player','999/999'],['mobile-battle','/battlePanel/piles','99999']]){
  const c=snapshots[name].nodes.find(c=>c.path===path&&c.visible);assert.ok(c,name+path);assert.equal(c.text,copy);assert.ok(c.font>=28);assert.equal(c.minimum,c.font);
 }
 const detail=snapshots['mobile-detail'].nodes.find(c=>c.path==='/deckPanel/details'&&c.visible);assert.ok(detail);assert.ok(detail.font>=24);assert.equal(detail.minimum,detail.font);
 for(const name of ['mobile-pause','mobile-exit'])assert.ok(snapshots[name].nodes.some(c=>c.visible&&c.font>=22));
});
test('single-glyph potion identities have a readable box and valid fixed font range',()=>{
 const b=child(tree(),'battlePanel');for(let i=1;i<=5;i++){const potion=child(i<4?b:child(b,'potionHelp'),'potion'+i);for(const state of states){const label=child(child(potion,state),'label');assert.ok(label.text.fontSize>=20);assert.equal(label.text.fontSize,label.text.minFontSize);assert.ok(label.size[0]>=label.text.fontSize);}}
});
test('pile totals, captions and library filter labels retain complete native lines',()=>{
 const t=tree(),b=child(t,'battlePanel');
 for(const n of ['draw','discard']){budget(child(b,n),'999');const caption=child(b,n+'Label');budget(caption,caption.text.content);assert.ok(Math.abs(caption.position[1])+caption.size[1]/2<=340);}
 for(const name of ['All','Attack','Skill','Power','Status','Curse'])for(const state of states){const c=child(child(child(child(t,'deckPanel'),'filter'+name),'hit'),state);budget(child(c,'label'),child(c,'label').text.content);}
});
test('full card reading uses 28-unit text and comfortable line pitch',()=>{
 const t=tree(),info=child(child(t,'battlePanel'),'statusInfo');assert.ok(child(child(t,'deckPanel'),'details').text.fontSize>=28);assert.ok(child(info,'text1').text.fontSize>=28);assert.ok(theme.layout.statusInfo.line>=34);
});
test('reward headings reserve a complete large-text line without displacing relics or hovering cards',()=>{
 const layout=theme.layout,battle=child(tree(),'battlePanel');
 for(const name of ['rewardStage','rewardList']){
  const title=child(child(battle,name),'title');
  assert.equal(title.text.fontSize,theme.font.title,'panel headings use the readable title role');
  assert.equal(title.text.minFontSize,title.text.fontSize);
 }
 for(const panel of [layout.rewardPick,layout.battleRewards,layout.battleRewards.expanded]){
  const title=panel.title,subtitle=panel.subtitle,stage=panel.stage;
  assert.ok(title[3]>=theme.font.title*1.3,'large title must fit the preview font line instead of clipping');
  assert.ok(title[1]-title[3]/2>=subtitle[1]+subtitle[3]/2,'title and subtitle remain separate');
  assert.ok(title[1]+title[3]/2<=stage[1]+stage[3]/2,'heading remains inside its original panel');
 }
 const pick=layout.rewardPick;
 assert.equal(pick.stage[1]+pick.stage[3]/2,254,'keep the frame below the existing relic bar');
 const card=layout.card;
 const costTop=pick.y+pick.hoverLift+(card.size[1]/2-card.costDisc/2+card.trim.costOverhang+layout.nativeText.lineHeight/2)*pick.hoverScale;
 assert.ok(pick.subtitle[1]-pick.subtitle[3]/2>=costTop+1,'preserve the existing gap above the hovered cost text');
});
test('noncombat potion management keeps its count on the main row clear of notices',()=>{
 const t=tree(),open=child(child(t,'potionEntry'),'open');assert.equal(open.position[1],316);
 for(const s of states){const label=child(child(child(open,'hit'),s),'label');assert.notEqual(label.visible,false);budget(label,'药水 5/5');}
 const node=child(t,'nodePanel');for(const n of ['deckIcon','deck','potions','relics'])assert.equal(child(node,n).visible,false,'shared host supplies '+n);
});
test('pressed and destructive action text keeps normal-text contrast',()=>{
 const t=tree();for(const panel of ['exitPanel','runMenu','deckPanel','potionPanel']){const p=child(t,panel);for(const action of p.children.filter(c=>c.children?.some(n=>n.kind==='presetButton'))){const hit=child(action,'hit');for(const s of states){const v=child(hit,s),label=child(v,'label'),plate=child(v,'plate');assert.ok(contrast(label.text.colour,plate.colour)>=4.5,`${panel}/${action.name}/${s}`);}}}
});
test('readable pile captions clear energy and end-turn controls with safe action gaps',()=>{
 const b=child(tree(),'battlePanel'),energy=child(b,'energyRing'),turn=child(b,'endTurn');
 const draw=child(b,'drawLabel'),discard=child(b,'discardLabel');
 assert.ok(energy.position[1]-energy.size[1]/2>=draw.position[1]+draw.size[1]/2+2,'draw caption clears energy');
 assert.ok(turn.position[1]-turn.size[1]/2>=discard.position[1]+discard.size[1]/2+16,'discard caption clears irreversible action');
});
test('owned relics and managed potions retain complete large-copy native frames',()=>{
 const t=tree(),relic=child(child(t,'relicPanel'),'row1');
 for(const name of ['name'])assert.ok(child(relic,name).size[1]>=40);
 assert.ok(child(child(relic,'chip'),'label').size[1]>=40);
 const description=child(relic,'description');assert.ok(description.size[1]>=160,'80-character relic copy needs four 40-unit native lines');
 const potion=child(t,'potionPanel');assert.ok(child(potion,'detail').size[1]>=160,'long copy and event restriction need four native lines');
 for(let i=1;i<=5;i++)for(const state of states)assert.ok(child(child(child(potion,'slot'+i),'hit'),state).children.find(c=>c.name==='label').size[1]>=80);
 assert.ok(theme.layout.potionPopup.line>=40,'explicit multiline popup copy reserves native lines');
});
