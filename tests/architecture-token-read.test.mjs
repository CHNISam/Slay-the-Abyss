import test from 'node:test';
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFileSync,mkdtempSync,rmSync,mkdirSync,cpSync,writeFileSync} from 'node:fs';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {fileURLToPath} from 'node:url';

test('foreign tokens avoid owner reads while equivalent sources freshly reject actual linked-owner drift',()=>{
 const directory=mkdtempSync(join(tmpdir(),'abyss-token-fs-trace-')),reads={};
 try{
  for(const mode of ['foreign','equivalent','fresh-owner']){
   const output=join(directory,mode+'.json');
   const result=spawnSync(process.execPath,['--trace-event-file-pattern='+output,fileURLToPath(new URL('./helpers/architecture-token-read-probe.mjs',import.meta.url)),mode],{encoding:'utf8',timeout:30000,maxBuffer:1024*1024,windowsHide:true});
   assert.ifError(result.error);assert.equal(result.status,0,result.stdout+result.stderr);
   const events=JSON.parse(readFileSync(output,'utf8')).traceEvents;
   if(process.env.ABYSS_SOURCE_EVIDENCE_DIR){
    const evidence=process.env.ABYSS_SOURCE_EVIDENCE_DIR;mkdirSync(evidence,{recursive:true});
    cpSync(output,join(evidence,'architecture-token-'+mode+'.trace.json'));
    writeFileSync(join(evidence,'architecture-token-'+mode+'.stdout.log'),result.stdout);
    writeFileSync(join(evidence,'architecture-token-'+mode+'.stderr.log'),result.stderr);
   }
   reads[mode]=events.filter(event=>event.ph==='B'&&event.name.startsWith('fs.sync.read')).length;
   if(mode==='fresh-owner')assert.equal(JSON.parse(result.stdout).changed,true);
  }
  assert.equal(reads.foreign,1,'only the live config itself is read; foreign tokens never read linked owners');
  assert.ok(reads.equivalent>reads.foreign,'equivalent input performs real linked-owner reads');
  assert.ok(reads['fresh-owner']>reads.foreign,'a successful warm call cannot suppress subsequent real owner validation');
  process.stdout.write('ARCHITECTURE_TOKEN_FS_READS '+JSON.stringify(reads)+'\n');
 }finally{rmSync(directory,{recursive:true,force:true});}
});
