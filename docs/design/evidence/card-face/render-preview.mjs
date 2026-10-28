import {readFileSync,writeFileSync}from'node:fs';
import{cardFaceChildren}from'../../../../scripts/card-face.mjs';
import{nativeTheme as theme}from'../../../../scripts/native-ui-theme.mjs';
const states=JSON.parse(readFileSync('docs/design/evidence/card-face/runtime-state.json','utf8'));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const colour=c=>typeof c==='string'?c:`rgb(${c.r} ${c.g} ${c.b})`;
function draw(spec,state={}){
 if(state.visible===false||state.visible===undefined&&spec.visible===false||spec.kind==='cursorArea')return '';
 const [x,y]=spec.position||[0,0],[w,h]=spec.size||[0,0];
 const transform=`translate(${x} ${-y})${spec.rotation?` rotate(${-spec.rotation})`:''}`;
 let inside='';
 if(spec.children)inside=spec.children.map(c=>draw(c,state.children?.[c.name])).join('');
 else if(spec.kind==='image'){
 const id=state.imageId||spec.image,fill=colour(state.imageColor||spec.colour||'#fff');
 const attrs=`fill="${fill}" opacity="${spec.opacity??1}"`;
 if(id===100002||id===106025)inside=`<ellipse rx="${w/2}" ry="${h/2}" ${attrs}/>`;
 else if(id===100006)inside=`<ellipse rx="${w/2-1}" ry="${h/2-1}" fill="none" stroke="${fill}" stroke-width="2"/>`;
 else if(id===100003)inside=`<path d="M0 ${-h/2}L${w/2} ${h/2}H${-w/2}Z" ${attrs}/>`;
 else if([100004,100005].includes(id))inside=`<path d="M0 ${-h/2}L${w*.13} ${-h*.13}L${w/2} 0L${w*.13} ${h*.13}L0 ${h/2}L${-w*.13} ${h*.13}L${-w/2} 0L${-w*.13} ${-h*.13}Z" ${attrs}/>`;
 else if(spec.name==='art')inside=`<text text-anchor="middle" dominant-baseline="middle" fill="${fill}" opacity=".6" font-size="28">◇</text>`;
 else if(spec.name==='glow')inside='';
 else inside=`<rect x="${-w/2}" y="${-h/2}" width="${w}" height="${h}" ${attrs}/>`;
 }else if(spec.kind==='text'){
 const size=state.fontSize||spec.text.fontSize,fill=colour(state.fontColor||spec.text.colour);
 const text=state.text||spec.text.content||'';const lines=text.split('\n');
 inside=lines.map((line,i)=>`<text x="0" y="${(i-(lines.length-1)/2)*size*1.4}" text-anchor="middle" dominant-baseline="central" font-size="${size}" fill="${fill}">${esc(line)}</text>`).join('');
 }
 return `<g transform="${transform}">${inside}</g>`;
}
const face=cardFaceChildren(theme,'battle');
const cards=states.map((s,i)=>`<g transform="translate(${110+i*180} 155)">${face.map(c=>draw(c,s.children[c.name])).join('')}<text y="140" text-anchor="middle" fill="#ddd" font-size="12">${['胡桃 · 减费','芙宁娜 · 加费','雷电 · 能力','阿蕾奇诺 · 禁用','旅行者 · 无费用','无色 · 减费'][i]}</text></g>`).join('');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="330" style="background:#20222b;font-family:Microsoft YaHei"><text x="20" y="22" fill="white" font-size="14">原生装配 1×（148×208）· Lua运行时状态 · 类型图标示意，非实机截图</text>${cards}</svg>`;
writeFileSync('docs/design/evidence/card-face/native-1x.svg',svg);
// Render the approved DC logic/template locally. Only the original <sc-if>/<sc-for> constructs are expanded.
const source=readFileSync('docs/design/ui-canvas/Card.dc.html','utf8');
const logic=source.match(/class Component extends DCLogic \{([\s\S]*)\}\s*<\/script>/)[1];
const Component=Function('DCLogic',`return class extends DCLogic {${logic}}`)(class{});
const roles=['hutao','furina','raiden','arlecchino','traveler','colorless'];
const types=['attack','skill','power','attack','skill','power'];
const refs=states.map((s,i)=>{
 const component=new Component();component.props={role:roles[i],rarity:['common','uncommon','rare','basic','basic','rare'][i],shape:types[i],title:s.children.name.text,typeLabel:s.children.type.text,cost:s.children.cost.text,text:s.children.label.text,costState:i===0||i===5?'down':i===1?'up':'normal',block:i===3?'condition':'none'};
 const vals=component.renderVals();let html=source.match(/<x-dc>([\s\S]*?)<\/x-dc>/)[1].replace(/<helmet>[\s\S]*?<\/helmet>/,'');
 function interpolate(text,env){return text.replace(/{{\s*([^}]+?)\s*}}/g,(_,key)=>key.split('.').reduce((v,k)=>v?.[k],env)??'');}
 html=html.replace(/<sc-for[^>]*>([\s\S]*?)<\/sc-for>/g,(_,body)=>vals.segments.map(seg=>interpolate(body,{...vals,seg})).join(''));
 html=html.replace(/<sc-if value="{{\s*(\w+)\s*}}"[^>]*>([\s\S]*?)<\/sc-if>/g,(_,key,body)=>vals[key]?body:'');
 html=interpolate(html,vals);
 return `<div style="width:180px;height:260px"><div style="transform:scale(.5);transform-origin:top left">${html}</div></div>`;
}).join('');
writeFileSync('docs/design/evidence/card-face/compare.html',`<!doctype html><meta charset="utf-8"><title>共享卡面 1× 对照</title><body style="margin:20px;background:#20222b;color:#eee;font-family:Microsoft YaHei"><p>批准稿 Card.dc.html 原模板（296×416 缩为 1×）</p><div style="display:flex;margin-left:16px">${refs}</div><img src="native-1x.svg"><p>下排使用生产装配器及 Lua 皮肤状态。原生图片按几何轮廓示意；纹理抗锯齿、类型图标与发光须在客户端核对。文字保留原生最低14px与全文预算，因此插画窗沿用64高，原稿79高另见差异记录。</p></body>`);
console.log('Wrote native-1x.svg and compare.html');
