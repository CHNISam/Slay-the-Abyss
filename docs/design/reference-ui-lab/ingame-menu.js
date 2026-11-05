import {SUPPORT_COPY} from './result-model.js';
// A deliberately limited gameplay-controls extraction, not a rebuilt settings page.
// Exact behavior reference: aeubanks/sts@319009d5, TopPanel, SettingsScreen,
// ExitGameButton, AbandonRunButton and ConfirmPopup. See MENU-REFERENCE.md.
const active = new WeakMap();
function styles(){
 if(document.querySelector('link[data-ingame-menu]'))return;
 const link=document.createElement('link');link.rel='stylesheet';link.href=new URL('./ingame-menu.css',import.meta.url).href;link.dataset.ingameMenu='';document.head.append(link);
}
function modal(host,attribute){
 styles();active.get(host)?.();
 const previous=document.activeElement;
 const siblings=[...host.children].map(element=>({element,inert:element.inert}));
 for(const {element} of siblings)element.inert=true;
 const overlay=document.createElement('section');overlay.className='ig-overlay';overlay.setAttribute(attribute,'');overlay.setAttribute('role','dialog');overlay.setAttribute('aria-modal','true');host.append(overlay);
 let closed=false;
 const close=()=>{if(closed)return;closed=true;overlay.remove();for(const {element,inert} of siblings)element.inert=inert;active.delete(host);if(previous?.isConnected)previous.focus()};
 active.set(host,close);
 overlay.addEventListener('keydown',event=>{
  if(event.key==='Escape'){event.preventDefault();event.stopPropagation();const back=overlay.querySelector('[data-confirm-back]');if(back)back.click();else close();}
  if(event.key==='Tab'){const buttons=[...overlay.querySelectorAll('button:not(:disabled),a[href]')];if(!buttons.length)return;const index=buttons.indexOf(document.activeElement);event.preventDefault();buttons[(index+(event.shiftKey?-1:1)+buttons.length)%buttons.length].focus()}
 });
 return {overlay,close};
}
export function closeGameMenu(host){active.get(host)?.()}
export function openGameMenu(host,{origin='map',onSaveExit=()=>{},onAbandon=()=>{},canSave=true}={}){
 const {overlay,close}=modal(host,'data-game-menu');overlay.setAttribute('aria-label','游戏菜单');
 function draw(){
  overlay.innerHTML=`<button class="ig-toggle" data-menu-close aria-label="关闭游戏菜单">⚙</button><h1 class="ig-heading">游戏菜单</h1><p class="ig-origin">${origin==='battle'?'战斗':origin==='map'?'地图':'当前场景'}已暂停</p><button class="ig-abandon" data-abandon>放弃本局</button><button class="ig-return" data-resume>返回游戏</button><button class="ig-save" data-save-exit>退出本局</button>`;
  overlay.querySelector('[data-menu-close]').onclick=close;
  overlay.querySelector('[data-resume]').onclick=close;
  overlay.querySelector('[data-abandon]').onclick=()=>confirm('abandon');
  overlay.querySelector('[data-save-exit]').onclick=()=>confirm('save');
  overlay.querySelector('[data-resume]').focus();
 }
 function confirm(kind){
  const abandon=kind==='abandon';
  overlay.innerHTML=`<article class="ig-confirm"><h2>${abandon?'放弃本局？':'确认退出本局？'}</h2><p>退出后本局结束，进度无法恢复。<br>正式游戏将进入平台结算，随后可选择离开。</p><p class="ig-save-limitation">${SUPPORT_COPY}</p><p class="ig-prototype-note">此处演示退出流程，不会向平台提交结果。</p><p class="ig-error" role="status"></p><div><button data-confirm-back>取消</button><button data-confirm-go>${abandon?'放弃本局':'退出本局'}</button></div></article>`;
  overlay.querySelector('[data-confirm-back]').onclick=draw;
  overlay.querySelector('[data-confirm-go]').onclick=()=>{try{(abandon?onAbandon:onSaveExit)();close()}catch(error){overlay.querySelector('.ig-error').textContent='未能结束本局，尚未退出。请取消后继续游戏。'}};
  overlay.querySelector('[data-confirm-back]').focus();
 }
 draw();return close;
}
export function openExitPrompt(host){
 const {overlay,close}=modal(host,'data-exit-prompt');overlay.setAttribute('aria-label','退出游戏');
 overlay.innerHTML='<article class="ig-confirm"><h2>退出游戏？</h2><p>将尝试关闭当前标签页。若浏览器不允许，请手动关闭标签页。</p><p class="ig-error" role="status" aria-live="polite"></p><div><button data-cancel-exit>取消</button><button data-close-window>退出游戏</button></div></article>';
 overlay.querySelector('[data-cancel-exit]').onclick=close;
 overlay.querySelector('[data-close-window]').onclick=()=>{
  try{window.close()}catch{}
  // close() has no success return value. An open document must never claim exit.
  if(overlay.isConnected)overlay.querySelector('.ig-error').textContent='如果标签页仍然打开，请使用浏览器关闭按钮。本局进度无法恢复。';
 };
 overlay.querySelector('[data-cancel-exit]').focus();return close;
}
