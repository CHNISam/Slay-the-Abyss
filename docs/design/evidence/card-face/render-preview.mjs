import {readFileSync,writeFileSync,mkdirSync}from'node:fs';
import{cardFaceChildren}from'../../../../scripts/card-face.mjs';
import{nativeTheme as theme}from'../../../../scripts/native-ui-theme.mjs';
const source=readFileSync('docs/design/ui-canvas/Card.dc.html','utf8');
const lockPath=source.match(/<path d="(M3\.5[^"]+)"/)[1];
const output=process.argv[3]??'docs/design/evidence/card-face';mkdirSync(output,{recursive:true});
const states=JSON.parse(readFileSync(process.argv[2]??'docs/design/evidence/card-face/runtime-state.json','utf8'));
const esc=s=>String(s).replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('"','&quot;');
const inline=s=>s.split(/(<color=#[0-9A-Fa-f]{6}>|<\/color>)/g).map(part=>/^<color=#[0-9A-Fa-f]{6}>$/.test(part)?`<tspan fill="${part.slice(7,14)}">`:part==='</color>'?'</tspan>':esc(part)).join('');
const colour=c=>typeof c==='string'?c:`rgb(${c.r} ${c.g} ${c.b})`;
// Conservative source glyph budget, not a claim about the platform font's exact metrics.
function wrapBody(value,width,size){
 if(value.includes('<color='))return value; // preserve rich spans; this fixture's body is plain text
 return value.split('\n').flatMap(line=>{
  let row='',used=0;const rows=[];
  for(const ch of line){
   const advance=(ch.codePointAt(0)>127?1:/[ilI.,:;! ]/.test(ch)?.35:/[MW]/.test(ch)?.9:.65)*size;
   if(row&&used+advance>width){rows.push(row);row='';used=0;}
   row+=ch;used+=advance;
  }
  rows.push(row);return rows;
 }).join('\n');
}
function draw(spec,state={}){
 if(state.visible===false||state.visible===undefined&&spec.visible===false||spec.kind==='cursorArea')return '';
 const [x,y]=[state.x??spec.position?.[0]??0,state.y??spec.position?.[1]??0],
  [w,h]=[state.sizeDeltaX??spec.size?.[0]??0,state.sizeDeltaY??spec.size?.[1]??0];
 const transform=`translate(${x} ${-y})${spec.rotation?` rotate(${-spec.rotation})`:''}${spec.scale?` scale(${spec.scale.join(' ')})`:''}`;
 let inside='';
 if(spec.children)inside=spec.children.map(c=>draw(c,state.children?.[c.name])).join('');
 else if(spec.kind==='image'){
 const id=state.imageId||spec.image,fill=colour(state.imageColor||spec.colour||'#fff');
 const attrs=`fill="${fill}" opacity="${spec.opacity??1}"`;
 if(id===100002||id===106025)inside=`<ellipse rx="${w/2}" ry="${h/2}" ${attrs}/>`;
 else if(id===100006)inside=`<ellipse rx="${w/2-1}" ry="${h/2-1}" fill="none" stroke="${fill}" stroke-width="2"/>`;
 else if(id===100003)inside=`<path d="M0 ${-h/2}L${w/2} ${h/2}H${-w/2}Z" ${attrs}/>`;
 else if([100004,100005].includes(id))inside=`<path d="M0 ${-h/2}L${w*.13} ${-h*.13}L${w/2} 0L${w*.13} ${h*.13}L0 ${h/2}L${-w*.13} ${h*.13}L${-w/2} 0L${-w*.13} ${-h*.13}Z" ${attrs}/>`;
 else if(spec.name==='blockedLock')inside=`<g transform="translate(${-w/2} ${-h/2}) scale(${w/14} ${h/16})"><path d="${lockPath}" fill="none" stroke="${fill}" stroke-width="2" stroke-linejoin="round"/></g>`;
 else if(spec.name==='art')inside=`<text text-anchor="middle" dominant-baseline="middle" fill="${fill}" opacity=".6" font-size="28">◇</text>`;
 else if(spec.name==='glow')inside='';
 else inside=`<rect x="${-w/2}" y="${-h/2}" width="${w}" height="${h}" ${attrs}/>`;
 }else if(spec.kind==='text'){
 const size=state.fontSize||spec.text.fontSize,fill=colour(state.fontColor||spec.text.colour);
 const raw=state.text||spec.text.content||'';
 const text=['label','description'].includes(spec.name)?wrapBody(raw,w,size):raw;const lines=text.split('\n');
 inside=lines.map((line,i)=>`<text x="0" y="${(i-(lines.length-1)/2)*size*1.4}" text-anchor="middle" dominant-baseline="central" font-size="${size}" fill="${fill}">${inline(line)}</text>`).join('');
 }
 return `<g transform="${transform}">${inside}</g>`;
}
const face=cardFaceChildren(theme,'battle');
const cards=states.map((s,i)=>`<g transform="translate(${110+i*180} 155)">${face.map(c=>draw(c,s.children[c.name])).join('')}<text y="140" text-anchor="middle" fill="#ddd" font-size="12">${['胡桃 · 减费','芙宁娜 · 加费','雷电 · 能力','阿蕾奇诺 · 禁用','旅行者 · 防御1费','无色 · 减费'][i]}</text></g>`).join('');
const svg=`<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="330" style="background:#20222b;font-family:Microsoft YaHei"><text x="20" y="22" fill="white" font-size="14">原生装配 1×（148×208）· Lua运行时状态 · 图库图标示意，非实机截图</text>${cards}</svg>`;
writeFileSync(output+'/native-1x.svg',svg);
// Render the approved DC logic/template locally. Only the original <sc-if>/<sc-for> constructs are expanded.

const logic=source.match(/class Component extends DCLogic \{([\s\S]*)\}\s*<\/script>/)[1];
const Component=Function('DCLogic',`return class extends DCLogic {${logic}}`)(class{});
const roles=['hutao','furina','raiden','arlecchino','traveler','colorless'];
const types=['attack','skill','power','attack','skill','power'];
const refs=states.map((s,i)=>{
 const upgraded=s.children.name.text.includes('<color=#8DE08A>＋');
 const title=s.children.name.text.replace(/<[^>]+>/g,'').replace(upgraded?/＋[0-9]*$/:/$^/,'');
 const component=new Component();component.props={role:roles[i],rarity:['common','uncommon','rare','basic','basic','rare'][i],shape:types[i],title,upgraded,typeLabel:s.children.type.text,cost:s.children.cost.text,text:s.children.label.text,costState:i===0||i===5?'down':i===1?'up':'normal',block:i===3?'condition':'none'};
 const vals=component.renderVals();let html=source.match(/<x-dc>([\s\S]*?)<\/x-dc>/)[1].replace(/<helmet>[\s\S]*?<\/helmet>/,'');
 function interpolate(text,env){return text.replace(/{{\s*([^}]+?)\s*}}/g,(_,key)=>key.split('.').reduce((v,k)=>v?.[k],env)??'');}
 html=html.replace(/<sc-for[^>]*>([\s\S]*?)<\/sc-for>/g,(_,body)=>vals.segments.map(seg=>interpolate(body,{...vals,seg})).join(''));
 html=html.replace(/<sc-if value="{{\s*(\w+)\s*}}"[^>]*>([\s\S]*?)<\/sc-if>/g,(_,key,body)=>vals[key]?body:'');
 html=interpolate(html,vals);
 return `<div style="width:180px;height:260px"><div style="transform:scale(.5);transform-origin:top left">${html}</div></div>`;
}).join('');
writeFileSync(output+'/compare.html',`<!doctype html><meta charset="utf-8"><title>共享卡面 1× 对照</title><body style="margin:20px;background:#20222b;color:#eee;font-family:Microsoft YaHei"><p>批准稿 Card.dc.html 原模板（296×416 缩为 1×）</p><div style="display:flex;margin-left:16px">${refs}</div><img src="native-1x.svg"><p>下排使用生产装配器及 Lua 皮肤状态。原生图片按几何轮廓示意；纹理抗锯齿、类型图标与发光须在客户端核对。文字保留原生最低14px与全文预算，因此插画窗沿用64高，原稿79高另见差异记录。</p></body>`);
console.log('Wrote native-1x.svg and compare.html');

for(const file of ['compare.html','native-1x.svg']){const path=output+'/'+file;writeFileSync(path,readFileSync(path,'utf8').split(/\r?\n/).map(line=>line.trimEnd()).join('\n').trimEnd()+'\n');}
