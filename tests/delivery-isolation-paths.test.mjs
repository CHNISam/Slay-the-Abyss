import test from'node:test';import assert from'node:assert/strict';import{mkdtempSync,mkdirSync,symlinkSync,rmSync,readFileSync,writeFileSync}from'node:fs';import{join,resolve}from'node:path';import{tmpdir}from'node:os';
import{requireIsolatedDeliveryPath,materializeBeforeDelivery,verifiedDeliverySources}from'./helpers/delivery-source-composition.mjs';
test('win32 and POSIX isolated copy boundaries accept children but reject roots escapes drives and UNC shares',()=>{
 for(const[style,root,inside,outside]of[
 ['win32','C:\\history',['C:\\history\\tests\\case.lua','C:/history/tests/case.lua'],['C:\\history','C:\\history-other\\case.lua','C:\\live\\case.lua','D:\\history\\case.lua','C:\\history\\..\\live\\case.lua']],
 ['win32','\\\\host\\share\\history',['\\\\host\\share\\history\\src\\case.lua'],['\\\\host\\share\\history','\\\\host\\other\\history\\case.lua','\\\\other\\share\\history\\case.lua']],
 ['posix','/history',['/history/tests/case.lua'],['/history','/history-other/case.lua','/live/case.lua','/history/../live/case.lua']]
 ]){for(const path of inside)assert.doesNotThrow(()=>requireIsolatedDeliveryPath(root,path,style));for(const path of outside)assert.throws(()=>requireIsolatedDeliveryPath(root,path,style),/isolated copy/);}
 assert.throws(()=>requireIsolatedDeliveryPath('/a','/a/b','unknown'),/syntax/);
});
test('a live tests junction is rejected unchanged; an owned copied test may be projected',()=>{
 const root=mkdtempSync(join(tmpdir(),'delivery-isolation-')),path='tests/exit-ui-layout.test.mjs',live=readFileSync(path,'utf8');
 try{symlinkSync(resolve('tests'),join(root,'tests'),'junction');assert.throws(()=>materializeBeforeDelivery(root),/isolated copy/);assert.equal(readFileSync(path,'utf8'),live);
 rmSync(join(root,'tests'));mkdirSync(join(root,'tests'));writeFileSync(join(root,path),live);materializeBeforeDelivery(root);
 assert.equal(readFileSync(join(root,path),'utf8'),new Map(verifiedDeliverySources('pre379')).get(path));assert.equal(readFileSync(path,'utf8'),live);
 }finally{rmSync(root,{recursive:true,force:true});}
});
