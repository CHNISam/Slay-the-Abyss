import {resultModel,SUPPORT_COPY} from './result-model.js';
import {characterReferenceData} from './character-reference.js';
export const RESULT_SAMPLES={victory:{outcome:'victory',scope:'two-acts',sample:true,floor:34,battlesWon:16,elapsedSeconds:2440,deck:26,hp:23,maxHp:80,gold:186,relics:8},defeat:{outcome:'defeat',sample:true,floor:8,battlesWon:5,elapsedSeconds:738,deck:14,hp:0,maxHp:80,gold:126,relics:3}};
function ensureStyles(){if(document.querySelector('link[data-results]'))return;const el=document.createElement('link');el.rel='stylesheet';el.href=new URL('./results.css',import.meta.url).href;el.dataset.results='';document.head.append(el)}
const ribbon=`<svg viewBox="0 0 650 112" preserveAspectRatio="none" aria-hidden="true"><defs><linearGradient id="result-paper" x2="0" y2="1"><stop stop-color="#b7ae89"/><stop offset="1" stop-color="#9b9273"/></linearGradient></defs><path d="M102 48 66 52 51 68 13 62 23 80 8 88 39 95 88 98 126 81H525L564 100 617 93 642 79 622 75 634 62 596 66 580 53 548 48Z" fill="#746e57" stroke="#3f3a30" stroke-width="3"/><path d="M103 23 127 15 278 12 376 8 374 14 518 17 546 27 552 82 532 91 515 84 139 83 110 94 98 79Z" fill="url(#result-paper)" stroke="#4e493b" stroke-width="3"/><path d="M113 87 134 80 158 83M519 83l22 5" stroke="#615b47" fill="none" stroke-width="3"/></svg>`;
export function renderResults(host,{data=RESULT_SAMPLES.victory,onRestart=()=>{},onReturn=()=>{},onChooseSample=()=>{}}={}){
 ensureStyles();const r=resultModel(data);const root=document.createElement('section');root.className='result-screen '+r.outcome;root.setAttribute('aria-label','本局结算');host.replaceChildren(root);
 root.innerHTML=`<div class="result-atmosphere" aria-hidden="true"></div><div class="result-hud"><span>${characterReferenceData.name}</span><span class="result-health">♥ ${r.hp}</span><span class="result-gold">● ${r.gold}</span><span class="result-floor">⌑ ${r.floor}</span><span>▱ ${r.deck}</span></div><div class="result-subject" aria-hidden="true"><img src="traveler-battle.png" alt=""></div><header class="result-banner">${ribbon}<h1>${r.title}</h1></header><p class="result-subtitle">${r.subtitle}</p>${r.sample?'<p class="result-fixture">独立结算样例 · 非本局战绩</p>':''}<dl class="result-stats"><div><dt>抵达层数</dt><dd>${r.floor}</dd></div><div><dt>战斗胜场</dt><dd>${r.battlesWon}</dd></div><div><dt>用时</dt><dd>${r.time}</dd></div><div><dt>卡组张数</dt><dd>${r.deck}</dd></div><div><dt>遗物件数</dt><dd>${r.relics}</dd></div><div class="result-stat-end"><dt>剩余生命</dt><dd>${r.hp}</dd></div></dl><div class="result-support"><strong>当前暂无存档功能</strong><p>${SUPPORT_COPY}</p></div><nav class="result-actions" aria-label="结算操作"><button class="result-secondary" data-restart>重新启程</button><button class="result-primary" data-settle>结束并结算<span>原型演示</span></button>${r.canViewEasterEgg?'<button class="result-easter" data-easter>查看彩蛋 <span>◇</span></button>':''}</nav><p class="result-contract">浏览器原型不会提交战绩；正式游戏才进入平台结算。重新启程不提交。</p><div class="result-sample-switch" aria-label="结算样例"><button data-sample="victory" aria-pressed="${r.outcome==='victory'}">胜利样例</button><button data-sample="defeat" aria-pressed="${r.outcome==='defeat'}">失败样例</button><a href="RESULT-REFERENCE.md" target="_blank" rel="noopener">参照与边界 ↗</a></div>`;
 root.querySelector('[data-restart]').onclick=onRestart;
 root.querySelectorAll('[data-sample]').forEach(b=>b.onclick=()=>onChooseSample(b.dataset.sample));
 function overlay(label,body){
  const previous=document.activeElement;const children=[...root.children];children.forEach(el=>el.inert=true);
  const modal=document.createElement('section');modal.className='result-modal';modal.setAttribute('role','dialog');modal.setAttribute('aria-modal','true');modal.setAttribute('aria-label',label);modal.innerHTML=body;root.append(modal);
  const close=()=>{modal.remove();children.forEach(el=>el.inert=false);if(previous?.isConnected)previous.focus()};
  modal.addEventListener('keydown',e=>{if(e.key==='Escape'){e.stopPropagation();close()}if(e.key==='Tab'){const controls=[...modal.querySelectorAll('button:not(:disabled),a[href]')];e.preventDefault();const i=controls.indexOf(document.activeElement);controls[(i+(e.shiftKey?-1:1)+controls.length)%controls.length]?.focus()}});
  modal.querySelectorAll('[data-close]').forEach(b=>b.onclick=close);modal.querySelector('[data-close]')?.focus();return {modal,close};
 }
 root.querySelector('[data-settle]').onclick=()=>{
  const {modal}=overlay('平台结算演示','<article class="result-platform"><h2>平台结算入口</h2><p>当前是浏览器界面原型，未连接千星奇域结算。<br>本次点击没有提交战绩。</p><p class="result-platform-note">正式游戏将在此提交胜负结果，再由平台提供离开关卡的选项。</p><div><button data-close>返回结算</button><button data-menu>返回主菜单</button></div></article>');
  modal.querySelector('[data-menu]').onclick=onReturn;
 };
 root.querySelector('[data-easter]')?.addEventListener('click',()=>{
  overlay('胜利彩蛋参照','<article class="result-platform"><h2>感谢您的游玩~！</h2><p>彩蛋画面仅保留在私人参考站，公开副本不分发第三方画面。</p><p>正式游戏的胜利页手动入口与返回流程保留，图像使用范围仍按项目素材许可核对。</p><a href="RESULT-REFERENCE.md" target="_blank" rel="noopener">查看彩蛋来源与平台边界</a><div><button data-close>返回结算</button></div></article>');
 });
 return root;
}
