/* Private Slay the Spire layout study. These rooms use independent fixtures,
 * not generated run state. Shared HUD is supplied by app.js via room-state.
 * References viewed before this pass:
 * https://interfaceingame.com/screenshots/slay-the-spire-store/
 * https://interfaceingame.com/screenshots/slay-the-spire-rest-or-smith/
 * https://playcraft.space/gallery/slay-the-spire/event-mind-bloom-choice/
 * https://interfaceingame.com/screenshots/slay-the-spire-choose-a-card-2/
 * No complete reference screenshot is embedded. Existing card components are
 * private-study assets, rights unconfirmed. Card/scene/item icons are placeholders.
 */
import {projectCards,typeNames,rarityNames} from './project-cards.js';
const cardById=new Map(projectCards.map(card=>[card.id,card]));
// Deliberate visual samples, not generated rewards or the player's deck.
const cards=['cleave','shockwave','barricade'].map(id=>cardById.get(id));
// Retain the existing demonstration prices; these are not project price rules.
const stock=[['cleave',50],['iron_wave',50],['shrug_it_off',50],['shockwave',50],['inflame',75],['impervious',99],['barricade',174]].map(([id,price])=>({...cardById.get(id),price}));
const sessions=new WeakMap();
const asset=name=>new URL(name,import.meta.url).href;
const art=(name,cls='')=>`<img class="${cls}" src="${asset(name)}" alt="">`;
const names={shop:'商店',camp:'营地',event:'事件',rewards:'战斗奖励'};
export function cardFace(c,upgraded=false){
 const kind=c.type;const frameRarity=['uncommon','rare'].includes(c.rarity)?c.rarity:'common';
 const cost=upgraded?(c.upgradeCost??c.cost):c.cost;
 const text=upgraded?(c.upgradeText??c.text):c.text;
 const label=`${c.name}${upgraded?'+':''} · ${rarityNames[c.rarity]}${typeNames[kind]} · 费用 ${cost}`;
 return `<div class="gr-card gr-card-${kind} project-card-theme${upgraded?' gr-upgraded':''}" data-card-id="${c.id}" data-rarity="${c.rarity}" title="${label}">${art(`geo-card-zhongli-${kind}.svg`,'gr-card-base')}<span class="gr-card-portrait-placeholder" aria-hidden="true"></span>${art(`sts-rarity-frame_${frameRarity}_${kind}.svg`,'gr-card-frame')}${art(`sts-rarity-banner_${frameRarity}.svg`,'gr-card-banner')}<span class="gr-cost">${cost}</span><strong>${c.name}${upgraded?'+':''}</strong>${art(`card-native-${kind}.svg`,'gr-card-icon')}<span class="gr-card-kind">${typeNames[kind]}</span><p>${text}</p></div>`;
}
const face=cardFace;
export function renderRoom(host,{page='shop',onNavigate=()=>{}}={}){
 if(!names[page])page='shop';
 if(!document.querySelector('link[data-genshin-rooms]')){const link=document.createElement('link');link.rel='stylesheet';link.href=asset('genshin-rooms.css');link.dataset.genshinRooms='';document.head.append(link)}
 let s=sessions.get(host);if(!s){s={gold:150,hp:42,maxHp:80,sold:[],campDone:false,upgrade:null,reward:null,eventDone:false};sessions.set(host,s)}
 const token={};s.token=token;
 let selection=null,mode='',notice='';
 const current=()=>s.token===token&&host.querySelector('.gr-room')?.dataset.page===page;
 function publish(){const detail={gold:s.gold,hp:s.hp,maxHp:s.maxHp,sold:[...s.sold],campDone:s.campDone,upgrade:s.upgrade,reward:s.reward,eventDone:s.eventDone};host.dataset.roomState=JSON.stringify(detail);host.dispatchEvent(new CustomEvent('room-state',{bubbles:true,detail}))}
 const nav=()=>{s.token=null;onNavigate('back')};
 function draw(){
  if(s.token!==token)return;
  host.innerHTML=`<section class="gr-room gr-${page}" data-page="${page}" aria-label="${names[page]}"><div class="gr-body">${page==='shop'?shop():page==='rewards'?rewards():page==='camp'?camp():event()}</div><p class="gr-sr-only" role="status" aria-live="polite">${notice}</p></section>`;
  host.querySelectorAll('[data-action]').forEach(b=>b.onclick=()=>{if(current()&&!b.disabled)act(b.dataset.action,b.dataset.id)});
  publish();
 }
 function product(c){const sold=s.sold.includes(c.id);return `<div class="gr-product-slot">${sold?`<span class="gr-sr-only">${c.name}已售出</span>`:`<button class="gr-product gr-stock-${c.id}" data-action="buy" data-id="${c.id}" aria-label="购买${c.name}，${rarityNames[c.rarity]}${typeNames[c.type]}，${c.price}金币" ${s.gold<c.price?'disabled':''}>${face(c)}<span class="gr-price">${c.price}</span></button>`}</div>`}
 function shop(){return `<main class="gr-shop-sheet" aria-label="商品"><div class="gr-products-top">${stock.slice(0,5).map(product).join('')}</div><div class="gr-products-bottom">${stock.slice(5).map(product).join('')}</div><div class="gr-shop-small-stock" aria-label="遗物与药水"><div class="gr-relic-stock">${[155,148,154].map((price,i)=>`<div class="gr-stock-placeholder" aria-label="遗物${i+1}">${art(['icon-102028.svg','icon-102034.svg','icon-102033.svg'][i])}<span class="gr-price">${price}</span></div>`).join('')}</div><div class="gr-potion-stock">${[73,48,51].map((price,i)=>`<div class="gr-stock-placeholder" aria-label="药水${i+1}">${art('icon-102025.svg')}<span class="gr-price">${price}</span></div>`).join('')}</div></div><div class="gr-removal-stock" aria-label="卡牌移除服务"><div class="gr-removal-card"><strong>卡牌移除<br>服务！</strong>${art('icon-deck.svg')}</div><span class="gr-price">75</span></div></main><button data-action="back" class="gr-leave">离开</button>`}
 function camp(){return `<main class="gr-camp-scene"><img class="gr-camp-traveler" src="traveler-battle.png" alt="旅行者，营地角色占位"><svg class="gr-campfire-placeholder" viewBox="0 0 480 460" role="img" aria-label="篝火场景占位"><ellipse cx="240" cy="418" rx="220" ry="34" fill="#0b0908"/><g stroke="#211713" stroke-width="44" stroke-linecap="round"><path d="m70 403 300-96M107 305l271 108M177 436l100-169M302 430l-92-171"/></g><g stroke="#6f4430" stroke-width="12" stroke-linecap="round"><path d="m70 400 300-96M107 302l271 108M177 433l100-169M302 427l-92-171"/></g><path d="M89 340c-58-116 52-132 13-231 90 87 29 114 83 145-6-100 72-130 44-245 109 118 34 167 80 226 31-74 16-132 71-178-25 115 94 189 33 291-28 53-270 85-324-8Z" fill="#c77939"/><path d="M130 344c-33-68 13-88 10-147 64 65 19 89 65 119-28-98 80-109 51-222 88 110 9 158 62 214 13-68 37-91 34-139 72 101 69 173 14 201-68 27-182 14-236-26Z" fill="#e8bc52"/><path d="M202 362c-25-65 42-98 29-144 74 58 20 101 62 145Z" fill="#f6e6a3"/></svg><div class="gr-camp-dialog${mode==='forge'?' gr-forging':''}"><h2>${s.campDone?(s.upgrade?'锻造完成':'休息完成'):mode==='forge'?'选择一张卡牌升级':'嗯……'}</h2>${campContent()}</div></main>${s.campDone?'<button class="gr-leave" data-action="back">继续</button>':''}`}
 function campContent(){
  if(s.campDone)return `<p class="gr-camp-result">${s.upgrade?`${s.upgrade}+`:`生命 ${s.hp} / ${s.maxHp}`}</p>`;
  if(mode==='forge')return `<div class="gr-upgrade-grid">${cards.map(c=>`<button class="gr-upgrade-card${selection===c.id?' gr-selected':''}" data-action="select" data-id="${c.id}" aria-pressed="${selection===c.id}">${face(c,selection===c.id)}</button>`).join('')}</div>${selection?`<p class="gr-upgrade-preview">${cards.find(c=>c.id===selection).upgradeText}</p>`:''}<div class="gr-upgrade-actions"><button data-action="cancel" class="gr-text-button">返回</button><button data-action="upgrade" class="gr-confirm" ${!selection?'disabled':''}>确认</button></div>`;
  return `<div class="gr-camp-choices"><button data-action="rest" aria-describedby="gr-rest-description"><span class="gr-camp-option-art gr-rest-art">呼……</span><strong>休息</strong><span id="gr-rest-description" class="gr-camp-description">回复最大生命的 30%（24）。</span></button><button data-action="forge" aria-describedby="gr-smith-description"><span class="gr-camp-option-art gr-smith-art">${art('card-native-attack.svg')}</span><strong>锻造</strong><span id="gr-smith-description" class="gr-camp-description">升级一张卡牌。</span></button></div>`;
 }
 function event(){return `<main class="gr-event-panel"><h2 class="gr-event-title">神职人员</h2><div class="gr-event-art" aria-label="神职人员插画位置">${art('icon-100114.svg')}</div><div class="gr-event-copy"><p class="gr-story">${s.eventDone?'一阵温暖的金色光芒包围了你。<br><br>治疗结束了。':'神职人员向你走来，提出为你治疗伤口。<br><br>你也可以请他净化你的牌组。'}</p><div class="gr-event-options">${s.eventDone?'':`<button data-action="heal" ${s.gold<35||s.hp===s.maxHp?'disabled':''}>[治疗] <span class="gr-cost-text">失去 35 金币。</span> <span class="gr-benefit-text">回复 20 点生命。</span></button><button disabled aria-label="净化，当前样例未实现">[净化] <span class="gr-cost-text">失去 50 金币。</span> <span class="gr-benefit-text">移除一张卡牌。</span></button>`}<button data-action="back">[离开]</button></div></div></main>`}
 function rewards(){return `<main class="gr-rewards-main"><h2 class="gr-reward-title">选择一张卡牌</h2><div class="gr-reward-grid">${cards.map(c=>`<button class="gr-reward-frame" data-action="claim" data-id="${c.id}" aria-label="选择${c.name}，${rarityNames[c.rarity]}${typeNames[c.type]}" ${s.reward?'disabled':''}>${face(c)}</button>`).join('')}</div><button data-action="skip" class="gr-skip" ${s.reward?'disabled':''}>跳过</button></main>`}
 function act(action,id){
  if(action==='back'){nav();return}
  if(action==='buy'&&page==='shop'){const c=stock.find(c=>c.id===id);if(c&&!s.sold.includes(c.id)&&s.gold>=c.price){s.gold-=c.price;s.sold.push(c.id);notice=`已购买${c.name}，剩余${s.gold}金币。`}}
  if(action==='forge'&&page==='camp'&&!s.campDone){mode='forge';selection=null}
  if(action==='select'&&page==='camp'&&!s.campDone&&mode==='forge'&&cards.some(c=>c.id===id)){selection=id}
  if(action==='cancel'){mode='';selection=null}
  if(action==='rest'&&page==='camp'&&!s.campDone){const healed=Math.min(24,s.maxHp-s.hp);s.hp+=healed;s.campDone=true;notice=`回复${healed}点生命。`}
  if(action==='upgrade'&&page==='camp'&&!s.campDone&&mode==='forge'&&selection){s.campDone=true;s.upgrade=cards.find(c=>c.id===selection).name;mode='';notice=`${s.upgrade}已升级。`}
  if(action==='heal'&&page==='event'&&!s.eventDone&&s.gold>=35&&s.hp<s.maxHp){s.hp+=Math.min(20,s.maxHp-s.hp);s.gold-=35;s.eventDone=true;notice='治疗完成。'}
  if(action==='claim'&&page==='rewards'&&!s.reward&&cards.some(c=>c.id===id)){s.reward=id;publish();nav();return}
  if(action==='skip'&&page==='rewards'&&!s.reward){s.reward='skip';publish();nav();return}
  draw();
 }
 draw();
 return ()=>{if(s.token===token){s.token=null;host.replaceChildren();delete host.dataset.roomState}};
}
