import {projectCards,starterCards,typeNames,rarityNames} from './project-cards.js';
import {cardFace} from './genshin-rooms.js?geo=power-unified';
const all=[...starterCards,...projectCards];let upgraded=false;
const rarity=document.querySelector('#rarity'),type=document.querySelector('#type'),toggle=document.querySelector('#upgrade');
function render(){const rows=all.filter(c=>(rarity.value==='all'||c.rarity===rarity.value)&&(type.value==='all'||c.type===type.value));document.querySelector('#cards').innerHTML=rows.map(c=>`<article class="sample" aria-label="${c.name}，${rarityNames[c.rarity]}，${typeNames[c.type]}">${cardFace(c,upgraded)}<div class="card-caption">${rarityNames[c.rarity]} · ${typeNames[c.type]}</div><a class="source" href="${c.source.presentation.url}" target="_blank" rel="noopener">项目名称与描述来源</a></article>`).join('')||'<p class="empty">当前样例没有这一类型与稀有度的组合。</p>';toggle.textContent=upgraded?'查看升级前':'查看升级后';toggle.setAttribute('aria-pressed',String(upgraded));}
rarity.onchange=type.onchange=render;toggle.onclick=()=>{upgraded=!upgraded;render()};render();
