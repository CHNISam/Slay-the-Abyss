import {execFileSync} from 'node:child_process';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {gzipSync} from 'node:zlib';
const git=(...args)=>execFileSync('git',args,{encoding:'utf8',maxBuffer:32*1024*1024}).trim();
const revision=git('rev-parse','HEAD');
const report=JSON.parse(readFileSync('build/engineering-quality.json','utf8'));
if(report.status!=='reported'||report.revision!==revision||report.errors.length)throw Error('Fresh successful current-HEAD quality report required');
const out='docs/evidence/m9-baseline-20261103';mkdirSync(out,{recursive:true});
const blobs=git('ls-tree','-r','-l','-z',revision).split('\0').filter(Boolean).map(line=>{
 const m=/^(\d+) (\S+) ([a-f0-9]+)\s+(\d+|-)\t([\s\S]+)$/.exec(line);if(!m)throw Error('Unexpected tree row');
 return {path:m[5],type:m[2],oid:m[3],bytes:m[4]==='-'?null:Number(m[4])};
});
const classify=path=>{
 if(/^(?:docs\/(?:evidence|history|reviews)|\.artifacts)\//.test(path))return 'historical-evidence';
 if(/^tests\//.test(path))return 'active-regression';
 if(/native-art\.(?:lua|json)$/.test(path))return 'generated-art-source';
 if(/\.(?:png|jpg|jpeg|gif|webp|ogg|wav|mp3|mp4|zip|gil|gia|blend)$/i.test(path))return 'binary-asset';
 return 'reviewable-text-or-other';
};
for(const blob of blobs)blob.category=classify(blob.path);
const lfs=JSON.parse(git('lfs','ls-files','--json',revision));
const f=report.snapshot.modules.flatMap(m=>m.functions.map(row=>({...row,file:m.file})));
const summary={revision,tree:git('rev-parse','HEAD^{tree}'),createdAt:new Date().toISOString(),node:process.version,
 qualityContract:report.snapshot.contract,coverage:report.coverage,
 lines:report.snapshot.modules.reduce((n,m)=>n+m.lines,0),
 functionComplexity:{above15:f.filter(x=>x.kind==='function'&&x.complexity>15).length,above30:f.filter(x=>x.kind==='function'&&x.complexity>30).length,max:Math.max(...f.map(x=>x.complexity))},
 longestFunctions:f.filter(x=>x.kind==='function').toSorted((a,b)=>b.lines-a.lines).slice(0,20),
 largestModules:report.snapshot.modules.toSorted((a,b)=>b.lines-a.lines).slice(0,20).map(m=>({file:m.file,lines:m.lines})),
 uniqueDependencies:report.snapshot.dependencies.length,scc:report.snapshot.cycles.map(c=>({members:c.members,internalCallSites:c.edges.length})),
 diagnostics:report.snapshot.diagnostics.length,
 git:{blobs:blobs.length,blobBytes:blobs.reduce((n,b)=>n+(b.bytes??0),0),categories:Object.fromEntries([...new Set(blobs.map(b=>b.category))].map(c=>[c,{count:blobs.filter(b=>b.category===c).length,bytes:blobs.filter(b=>b.category===c).reduce((n,b)=>n+(b.bytes??0),0)}])),countObjects:git('count-objects','-v')},
 largestBlobs:blobs.toSorted((a,b)=>b.bytes-a.bytes).slice(0,40),
 lfs,limits:['Git blob bytes are not clone/pack or game installation size.','Category rules are triage, not authorization to delete or migrate.','No LFS download, history rewrite, asset migration or evidence deletion.','Official client/PC/mobile performance NOT_RUN.']};
writeFileSync(out+'/summary.json',JSON.stringify(summary,null,2)+'\n');
writeFileSync(out+'/git-blobs.json.gz',gzipSync(JSON.stringify(blobs)));
writeFileSync(out+'/quality.json.gz',gzipSync(JSON.stringify(report)));
const hashes=Object.fromEntries(['summary.json','git-blobs.json.gz','quality.json.gz'].map(name=>[name,createHash('sha256').update(readFileSync(out+'/'+name)).digest('hex')]));
writeFileSync(out+'/hashes.json',JSON.stringify({revision,hashes},null,2)+'\n');
console.log(JSON.stringify({revision,blobs:summary.git.blobs,blobBytes:summary.git.blobBytes,lfsCount:lfs.files?.length??lfs.length,hashes},null,2));
