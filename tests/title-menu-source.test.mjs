import test from'node:test';import assert from'node:assert/strict';import{readFileSync}from'node:fs';import{createHash}from'node:crypto';
import{titleMenuSourceProof as proof,preTitleMenuSource as project}from'./helpers/title-menu-source.mjs';
import{preHeroVisualSource}from'./helpers/hero-visual-source-inverse.mjs';
import{preAcceptedPr323Source,requirePr323Source}from'./helpers/pr323-accepted-source-inverse.mjs';
const p='tests/lua/title_menu_admission.lua',read=p=>readFileSync(p,'utf8'),sha=s=>createHash('sha256').update(s.replaceAll('\r\n','\n')).digest('hex');
test('only the exact current title-menu test restores the untouched historical witness',()=>{
 const raw=read(p).replaceAll('\r\n','\n'),b=proof.files[p],old=project(p,raw);assert.equal(raw.length,b.afterUtf16Length);assert.equal(sha(raw),b.afterSha256);assert.equal(sha(old),b.beforeSha256);assert.equal(project(p,old),old);assert.equal(project(p,raw.replaceAll('\n','\r\n')),old);
 for(const bad of [raw+'\n',raw.slice(1),raw+raw,'界'+raw.slice(1),'🙂'+raw.slice(2)])assert.equal(project(p,bad),bad);
 for(const h of b.hunks)for(const replacement of [[],h.before,[...h.after,...h.after],['-- unknown']]){const lines=raw.split('\n');lines.splice(h.at,h.after.length,...replacement);const bad=lines.join('\n');if(bad!==raw)assert.equal(project(p,bad),bad);}
 assert.equal(project('wrong',raw),raw);assert.equal(preHeroVisualSource(p,raw),preHeroVisualSource(p,old));requirePr323Source(p,raw);assert.equal(preAcceptedPr323Source(p,raw),preAcceptedPr323Source(p,old));assert.equal(read(p).replaceAll('\r\n','\n'),raw,'current test never rewritten or historically executed');
});
test('warm direct and hero entry projections retain caller-owned missing drift and same-length owner checks',()=>{
 const raw=read(p);for(const call of [project,preHeroVisualSource]){call(p,raw,{readSource:read});for(const bad of [undefined,raw+'\n','界'+raw.slice(1)])assert.throws(()=>call(p,raw,{readSource:q=>q===p?bad:read(q)}),/linked source/);}
});
