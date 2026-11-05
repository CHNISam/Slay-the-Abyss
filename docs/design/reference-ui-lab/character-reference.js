// Private browser study. Character identity and loadout are copied from the
// existing project, not the reference screenshot. See the source notes below.
export const characterReferenceData = Object.freeze({
  id: 'ironclad',
  name: '旅行者·荧 · 岩',
  maxHp: 80,
  startingGold: 99,
  relic: '余烬之心',
  relicText: '每场战斗结束时，回复 6 点生命。',
});

// Sources: abyss_character_select.lua (name), data/rules.json (80 HP / 99 gold),
// data/relics.json burning_blood (余烬之心, combat_end heal 6), and
// data/presentation/narrative.zh-CN.json (approved intro excerpts).
// Existing artwork: traveler-battle.png, menu-reference-background.png.
// constellation-exact.png supplies the exact silhouette and alpha; CSS applies
// the warm gold shown in the user's selection-screen reference.
const asset = name => new URL('./' + name, import.meta.url).href;
const mounted = new WeakMap();
let nextHeadingId = 0;

export function ensureCharacterReferenceStyles() {
  if (document.querySelector('link[data-character-reference]')) return;
  const link = document.createElement('link');
  link.rel = 'stylesheet';
  link.href = asset('character-reference.css');
  link.dataset.characterReference = '';
  document.head.append(link);
}

const lock = '<svg viewBox="0 0 36 42" aria-hidden="true"><path d="M9 18V12a9 9 0 0 1 18 0v6" fill="none" stroke="currentColor" stroke-width="4"/><rect x="4" y="17" width="28" height="23" rx="3" fill="currentColor"/><path d="M18 24a3 3 0 0 0-1.5 5.6L15 35h6l-1.5-5.4A3 3 0 0 0 18 24" fill="#363945"/></svg>';
const heart = '<svg viewBox="0 0 36 34" aria-hidden="true"><path d="M18 31C14 27 3 21 2 12 1 2 12 0 18 7 23 0 35 2 34 12 33 21 22 28 18 31Z" fill="currentColor" stroke="#432c2a" stroke-width="2"/><path d="M27 7c2 0 3 2 3 5" fill="none" stroke="#ffb2aa" stroke-width="3" stroke-linecap="round"/></svg>';
const coin = '<svg viewBox="0 0 36 40" aria-hidden="true"><path d="M13 3c4-2 11-2 14 1l-4 9c2 6 11 14 9 20-2 7-23 6-25 1-2-6 5-15 9-21Z" fill="currentColor" stroke="#45443b" stroke-width="2.5"/><path d="M15 13h9M14 14C7 13 6 20 2 18m12-2c-4 1-2 6-7 7" fill="none" stroke="#8b8d81" stroke-width="2.5" stroke-linecap="round"/><path d="m20 21-5 8h10m-3-8v12" fill="none" stroke="#77796c" stroke-width="2.5" stroke-linejoin="round"/></svg>';
// Control reference: https://interfaceingame.com/screenshots/slay-the-spire-choose-your-character/
// Inline SVGs approximate the original banners and resource icons for this study.
// They are not extracted game textures; original character artwork stays unchanged.
const backBanner = '<svg viewBox="0 0 180 60" preserveAspectRatio="none" aria-hidden="true"><path d="M-3 9H153Q170 9 174 2Q182 11 170 23Q162 30 151 33Q159 40 174 36Q181 45 169 53Q159 59 143 59H-3Z" fill="#8c3739" stroke="#bca348" stroke-width="2"/><path d="M-2 12H152Q168 12 173 7M-2 55H143Q160 55 171 46" fill="none" stroke="#b95b4a" stroke-width="1.5" opacity=".55"/></svg>';
const startBanner = '<svg viewBox="0 0 180 60" preserveAspectRatio="none" aria-hidden="true"><path d="M183 10H47C32 10 17 28 4 12C-2 29 8 45 26 53C36 58 45 59 56 59H183Z" fill="#477b89" stroke="#a2b4b5" stroke-width="2"/><path d="M180 13H48C32 13 18 30 7 17M8 32C17 51 37 55 55 56H182" fill="none" stroke="#77a4af" stroke-width="1.5" opacity=".6"/></svg>';

/** Render only the existing browser prototype's select / back / start flow.
 * Returns an idempotent listener cleanup. No storage, Run, RNG, or unlock state.
 */
export function renderCharacterReference(host, {
  onNavigate = () => {},
  onStart,
  onSelect = () => {},
} = {}) {
  mounted.get(host)?.();
  ensureCharacterReferenceStyles();
  const controller = new AbortController();
  const root = document.createElement('section');
  root.className = 'menus sts-menus character character-reference';
  root.setAttribute('aria-label', '选择角色');
  const data = characterReferenceData;
  const headingId = 'cr-character-name-' + ++nextHeadingId;
  root.innerHTML = `
    <div class="cr-landscape" aria-hidden="true"></div>
    <div class="cr-landscape-shade" aria-hidden="true"></div>
    <img class="cr-art" src="${asset('traveler-battle.png')}" alt="" aria-hidden="true" draggable="false">
    <div class="cr-foreground-shade" aria-hidden="true"></div>
    <header class="cr-header"><span class="cr-heading-emblem" aria-hidden="true">✦</span><span class="cr-heading-divider" aria-hidden="true"></span><h1>选择角色</h1><span class="cr-heading-rule" aria-hidden="true"></span></header>
    <article class="cr-copy" aria-labelledby="${headingId}">
      <h2 id="${headingId}">${data.name}</h2>
      <div class="cr-stats"><span class="cr-health"><span class="cr-heart">${heart}</span><span aria-label="生命 ${data.maxHp} / ${data.maxHp}">生命：${data.maxHp}/${data.maxHp}</span></span><span class="cr-gold"><span class="cr-coin">${coin}</span><span>金币：${data.startingGold}</span></span></div>
      <p class="cr-description">岩层深处传来了异常的共鸣。<br>旅行者，深入遗迹，阻止深渊的侵蚀。</p>
      <div class="cr-relic"><img class="cr-relic-icon" src="${asset('icon-geo.svg')}" alt="" aria-hidden="true"><div><span class="cr-relic-caption">初始遗物</span><h3>${data.relic}</h3><p>${data.relicText}</p></div></div>
    </article>
    <div class="cr-characters" role="group" aria-label="角色选择">
      <button type="button" class="cr-character is-selected" data-character="ironclad" aria-label="${data.name}，已选择" aria-pressed="true"><span class="cr-character-frame" aria-hidden="true"></span><span class="cr-constellation" aria-hidden="true"></span><span class="cr-selection-spark" aria-hidden="true">✦</span></button>
      ${[1, 2, 3].map(index => `<button type="button" class="cr-character is-locked" data-character="locked-${index}" disabled aria-disabled="true" aria-label="未开放角色 ${index}" title="暂未开放"><span class="cr-character-frame" aria-hidden="true"></span><span class="cr-lock">${lock}</span></button>`).join('')}
    </div>
    <button type="button" class="cr-action cr-back" data-back><span class="cr-action-banner" aria-hidden="true">${backBanner}</span><span class="cr-action-label">返回</span></button>
    <button type="button" class="cr-action cr-start" data-start><span class="cr-action-banner" aria-hidden="true">${startBanner}</span><span class="cr-action-label">开始挑战</span></button>`;
  host.replaceChildren(root);

  let departed = false;
  const listen = (selector, handler) => root.querySelector(selector).addEventListener('click', handler, {signal: controller.signal});
  const depart = callback => {
    if (departed) return;
    departed = true;
    root.querySelectorAll('button:not(:disabled)').forEach(button => {button.disabled = true;});
    callback();
  };
  listen('[data-character="ironclad"]', () => {if (!departed) onSelect(data.id);});
  listen('[data-back]', () => depart(() => onNavigate('menu')));
  listen('[data-start]', () => depart(() => typeof onStart === 'function' ? onStart() : onNavigate('map')));

  const cleanup = () => {
    controller.abort();
    if (mounted.get(host) === cleanup) mounted.delete(host);
  };
  mounted.set(host, cleanup);
  return cleanup;
}
