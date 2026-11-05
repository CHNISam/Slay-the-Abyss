const integer=(value,fallback=0)=>Number.isFinite(value)?Math.max(0,Math.floor(value)):fallback;
export const SUPPORT_COPY='存档功能需作者达到创作者 4 级后开放，喜欢的话欢迎点赞支持。帮助作者提升等级。';
export function resultModel(input={}){
 const outcome=input.outcome==='victory'?'victory':'defeat';
 const maxHp=Math.max(1,integer(input.maxHp,80));
 const seconds=Number.isFinite(input.elapsedSeconds)&&input.elapsedSeconds>=0?Math.floor(input.elapsedSeconds):null;
 return {outcome,canViewEasterEgg:outcome==='victory',title:outcome==='defeat'?'旅途在此中断':input.scope==='two-acts'?'双幕挑战完成':'深渊已被封印',subtitle:outcome==='victory'&&input.scope==='two-acts'?'第一幕与第二幕已完成。本局挑战到此结束。':'',floor:integer(input.floor),battlesWon:integer(input.battlesWon),deck:integer(input.deck),hp:Math.min(integer(input.hp),maxHp)+' / '+maxHp,gold:integer(input.gold),relics:integer(input.relics),score:Number.isFinite(input.score)?integer(input.score):null,time:seconds===null?'未记录':Math.floor(seconds/60)+':'+String(seconds%60).padStart(2,'0'),sample:input.sample===true};
}
