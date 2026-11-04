import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,writeFileSync,rmSync} from 'node:fs';
import {createHash} from 'node:crypto';
import {join} from 'node:path';
import {tmpdir} from 'node:os';
import {runLua} from '../scripts/test-lua.mjs';
import {luaString} from '../scripts/build-lua-data.mjs';
import {discoverSources} from '../scripts/lua-quality-metrics.mjs';
import {analyzeSources} from '../scripts/check-architecture.mjs';
const path='src/lua/abyss_living_wall.lua';
const normalize=s=>s.replaceAll('\r\n','\n');
const old=normalize(readFileSync('tests/fixtures/living-wall-copy-before.lua','utf8'));
test('LivingWall full-source oracle is authenticated to b4ac6314',()=>{
    assert.equal(createHash('sha256').update(old).digest('hex'),'5305065ae60d0938b7f95c2dfb4162f0e416170f637561274947500aaac2567f');
});
function replay(source,block=true){
    const dir=mkdtempSync(join(tmpdir(),'living-wall-copy-'));
    try{
        const file=join(dir,'driver.lua');
        writeFileSync(file,`package.path='src/lua/?.lua;build/lua/?.lua;'..package.path\nABYSS_LIVING_COPY_BLOCK=${block?'true':'false'}\nABYSS_LIVING_COPY_TRACE=true\n`
            +`package.preload.abyss_living_wall=function()return assert(load(${luaString(source)},'living-wall-copy-source'))()end\n`
            +"dofile('tests/lua/living_wall_copy_dependency.lua')\n");
        return runLua(file);
    }finally{rmSync(dir,{recursive:true,force:true});}
}
test('LivingWall read-only filtering works in a genuinely cold VM that rejects loading Combat',()=>{
    const result=runLua('tests/lua/living_wall_copy_dependency.lua');
    assert.equal(result.status,0,result.stdout+result.stderr);
    assert.match(result.stdout,/LIVING_COPY_COLD \d+ COMBAT false/);
    assert.match(result.stdout,/LIVING_COPY_PASS/);
});
test('fixed old and new sources preserve complete filtering/copy graphs and independently measured cold imports',()=>{
    const before=replay(old,false),after=replay(normalize(readFileSync(path,'utf8')),false);
    for(const result of [before,after])assert.equal(result.status,0,result.stdout+result.stderr);
    const trace=stdout=>stdout.split('\n').find(line=>line.startsWith('LIVING_COPY_TRACE '));
    assert.equal(trace(after.stdout),trace(before.stdout));
    const count=stdout=>Number(stdout.match(/LIVING_COPY_COLD (\d+)/)[1]);
    assert.match(before.stdout,/COMBAT true/);assert.match(after.stdout,/COMBAT false/);
    assert(count(after.stdout)<count(before.stdout));
    console.log(`LivingWall fresh VM imports ${count(before.stdout)} -> ${count(after.stdout)}; copy graph identical`);
    const regression=replay(old,true);
    assert.notEqual(regression.status,0);assert.match(regression.stderr,/\[LIVING_COPY\] pure read loaded Combat/);
});
test('LivingWall dependency boundary rejects real direct and delayed Combat regressions',()=>{
    const sources=Object.fromEntries(Object.entries(discoverSources()).map(([file,text])=>[file.slice(8,-4),text]));
    const config=JSON.parse(readFileSync('config/architecture.json','utf8'));
    const boundary=config.dependencyBoundaries.find(rule=>rule.id==='living-wall-copy-isolation');
    assert(boundary,'production dependency rule must be present');
    assert.deepEqual(boundary.from,['abyss_living_wall']);assert.deepEqual(boundary.forbiddenTargets,['abyss_combat']);
    assert.deepEqual(analyzeSources(sources,config).errors,[]);
    const source=sources.abyss_living_wall;
    for(const regression of [old,source.replace('return M',"local function forbidden()return require('abyss_combat')end\nreturn M")]){
        assert(analyzeSources({...sources,abyss_living_wall:regression},config).errors
            .some(error=>error.file===path&&error.message.includes('Dependency boundary living-wall-copy-isolation')));
    }
});
