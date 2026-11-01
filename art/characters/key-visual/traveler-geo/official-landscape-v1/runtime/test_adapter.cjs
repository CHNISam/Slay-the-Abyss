'use strict';
const test=require('node:test'), assert=require('node:assert/strict'), fs=require('node:fs'), path=require('node:path'), crypto=require('node:crypto');
const ROOT=path.resolve(__dirname,'../../../../../..');
const INPUT=process.env.BACKGROUND_INPUT||path.resolve(__dirname,'..');
const CHECKER=process.env.BACKGROUND_CHECKER||path.join(ROOT,'tests/fixtures/image-editor-103025-checker.cjs');
const FENGARI=process.env.BACKGROUND_FENGARI||'fengari';
const ADAPTER=process.env.BACKGROUND_ADAPTER||path.join(__dirname,'background_adapter.lua');
const SHA='fc0e4c50c0ed03a7a790731df5f5e10076d1418db615c41784210e9677c24ce3';
const hash=b=>crypto.createHash('sha256').update(b).digest('hex');
const original=fs.readFileSync(path.join(INPUT,'native-art.lua'));assert.equal(hash(original),SHA);
const native=JSON.parse(fs.readFileSync(path.join(INPUT,'native-art.json')));
const source=original.toString('utf8');
const literals=source.slice(source.indexOf('local ROOT = '),source.indexOf('\nlocal created = {}'));
assert(literals.startsWith('local ROOT = ')&&literals.includes('local ELEMENTS = {'));
const dataSource=literals+`\nreturn {sourceSha256='${SHA}',width=480,height=270,root=ROOT,rows=ELEMENTS}\n`;
const DATA_FILE=path.join(__dirname,'background_data.lua');
const runtimeDataSource=fs.existsSync(DATA_FILE)?fs.readFileSync(DATA_FILE,'utf8'):dataSource;
const adapterSource=fs.existsSync(ADAPTER)?fs.readFileSync(ADAPTER,'utf8'):'return {}';
const fixturePath=CHECKER, fixtureBytes=fs.readFileSync(fixturePath);
const blob=crypto.createHash('sha1').update(Buffer.from(`blob ${fixtureBytes.length}\0`)).update(fixtureBytes).digest('hex');
assert.equal(blob,'ced76db25cd9e386d9c2dd683ea8f0aeef1b35aa');
const fengari=require(FENGARI), {lua,lauxlib,lualib,to_luastring}=fengari;
let latest;
const newState=lauxlib.luaL_newstate;lauxlib.luaL_newstate=()=>latest=newState();
const open=lualib.luaL_openlibs;lualib.luaL_openlibs=L=>{open(L);assert.equal(lauxlib.luaL_dostring(L,to_luastring('io=nil;os=nil;package=nil;require=nil;dofile=nil;loadfile=nil;load=nil;fengari=nil')),lua.LUA_OK);};
const fixture=fixtureBytes.toString('utf8'),begin=fixture.indexOf('function vm(script) {'),end=fixture.indexOf('\nvm(source)(');
assert(begin>0&&end>begin);
const exactVm=require('node:vm').runInThisContext('(function(deps){const {assert,lua,lauxlib,lualib,to_luastring,to_jsstring,maskSlots,controlCount}=deps;'+fixture.slice(begin,end)+';return vm;})')({...fengari,assert,maskSlots:[],controlCount:13201});
function withVm(code){
 const run=exactVm(`Adapter=(function()\n${adapterSource}\nend)(); data=(function()\n${runtimeDataSource}\nend)(); assert(type(Adapter.new)=='function','background adapter factory is not implemented')`),state=latest;
 try{
  run(`host=script.object
function LiveCount() local n=0;for _,c in ipairs(controls)do if c.alive then n=n+1 end end;return n end
function New(batch) return Adapter.new(host,data,{imagePrefabId=1234,batchSize=batch or 64}) end
function Ready(a) local guard=0;while a:status().phase=='building' do a:tick(a:status().generation);guard=guard+1;assert(guard<=13202)end end
`); run(code);
 }finally{lua.lua_close(state);}
}
test('frozen full export and every literal row remain bound to the editable JSON',()=>{
 const lines=literals.split('\n').filter(l=>/^\s*\{100001,/.test(l));assert.equal(lines.length,13201);assert.equal(native.elements.length,13201);
 for(let i=0;i<lines.length;i++){
  const vals=lines[i].trim().slice(1,-2).split(',').map(Number),e=native.elements[i];
  assert(vals.every(Number.isFinite));assert.equal(e.type,'rectangle');
  assert.deepEqual(vals,[100001,e.x-240,135-e.y,e.width,e.height,.5,.5,.5,.5,.5,.5,1,1,0,...[1,3,5].map(n=>parseInt(e.color.slice(n,n+2),16)),255]);
 }
});
test('bounded hidden creation, exact 13201 row properties/order, 8/3 fit, static idempotence',()=>withVm(`
a=New(64);local ok,g=a:begin();assert(ok and #controls==0 and not host.visible)
local ticks=0
while a:status().phase=='building' do
 local before=#controls;assert(a:tick(g));assert(#controls-before<=64);ticks=ticks+1
 if a:status().phase=='building' then assert(not host.visible) end
end
assert(ticks==207 and #controls==13201 and LiveCount()==13201 and host.visible)
assert(host.SetSizeDeltaValue[1]==480 and host.SetSizeDeltaValue[2]==270)
assert(math.abs(host.SetLocalScaleValue[1]-8/3)<1e-12 and math.abs(host.SetLocalScaleValue[2]-8/3)<1e-12)
for i,r in ipairs(data.rows)do
 local c=controls[i];assert(c.parent==host and c.asset==r[1] and c.source=='static' and c.top and c.visible and c.active)
 local checks={{c.SetAnchoredPositionValue,{r[2],r[3]}},{c.SetSizeDeltaValue,{r[4],r[5]}},{c.SetPivotValue,{r[6],r[7]}},{c.SetAnchorMinValue,{r[8],r[9]}},{c.SetAnchorMaxValue,{r[10],r[11]}},{c.SetLocalScaleValue,{r[12],r[13],1}},{c.SetLocalRotationValue,{0,0,r[14]}},{c.imageColor,{r[15],r[16],r[17],r[18]}}}
 for _,pair in ipairs(checks)do for j,v in ipairs(pair[2])do assert(pair[1][j]==v,'row property mismatch '..i)end end
end
assert(New(64)==a);assert(a:begin());for i=1,5 do a:tick(g)end;assert(#controls==13201)
assert(a:release());assert(LiveCount()==0 and not host.visible);assert(a:release())
`));
test('stale generation and battle release prevent further creation or resurrection',()=>withVm(`
a=New(3);local _,g=a:begin();a:tick(g);assert(#controls==3);assert(a:release());local n=#controls
for i=1,5 do assert(not a:tick(g))end;assert(#controls==n and LiveCount()==0 and not host.visible)
local ok,g2=a:begin();assert(ok and g2~=g);assert(not a:tick(g));assert(#controls==n);a:tick(g2);assert(#controls==n+3);a:release()
`));
test('repeat begin and tick reentry during creation do not duplicate work',()=>withVm(`
a=New(4);local _,g=a:begin();local original=game.InstantiateClientUIControl;local calls=0
game.InstantiateClientUIControl=function(...)calls=calls+1;assert(not a:begin());assert(not a:tick(g));return original(...)end
a:tick(g);assert(calls==4 and #controls==4);a:release()
`));
test('release inside Instantiate invalidates returned control before any later row',()=>withVm(`
a=New(4);local _,g=a:begin();local original=game.InstantiateClientUIControl
game.InstantiateClientUIControl=function(...)local c=original(...);a:release();return c end
assert(not a:tick(g));assert(#controls==1 and LiveCount()==0 and not host.visible);assert(not a:tick(g))
`));
for(const mode of ['nil','throw','setter'])test('creation failure '+mode+' latches, rolls back, and retries explicitly',()=>withVm(`
a=New(8);local original=game.InstantiateClientUIControl;local calls=0
game.InstantiateClientUIControl=function(...)
 calls=calls+1;if calls==3 then ${mode==='nil'?'return nil':mode==='throw'?"error('create failure')":"local c=original(...);c.SetImage=function()error('setter failure')end;return c"} end
 return original(...)
end
local _,g=a:begin();assert(not a:tick(g));assert(a:status().phase=='failed' and LiveCount()==0 and not host.visible)
local n=#controls;assert(not a:begin());for i=1,3 do assert(not a:tick(g))end;assert(#controls==n)
game.InstantiateClientUIControl=original;assert(a:retry());a:tick(a:status().generation);assert(LiveCount()==8);a:release();assert(LiveCount()==0)
`));
test('setter cancellation stops the old job and cannot display partial art',()=>withVm(`
a=New(8);local original=game.InstantiateClientUIControl
game.InstantiateClientUIControl=function(...)local c=original(...);local set=c.SetImage;c.SetImage=function(...)set(...);a:release()end;return c end
local _,g=a:begin();assert(not a:tick(g));assert(#controls==1 and LiveCount()==0 and not host.visible)
`));
test('destroy failure is isolated and retained until explicit release retry',()=>withVm(`
a=New(4);a:begin();a:tick(a:status().generation);local original=game.DestroyClientUIControl;local attempts=0
game.DestroyClientUIControl=function(c)attempts=attempts+1;if c==controls[2]then error('destroy failure')end;original(c)end
assert(not a:release());assert(attempts==4 and LiveCount()==1 and a:status().retained==1 and not host.visible)
assert(not a:begin());assert(not a:tick(a:status().generation));game.DestroyClientUIControl=original
assert(a:release());assert(LiveCount()==0);assert(a:retry());a:tick(a:status().generation);assert(LiveCount()==4);a:release()
`));
test('engine destruction never calls Destroy again and permanently retires callbacks',()=>withVm(`
a=New(3);local _,g=a:begin();a:tick(g);local calls=0;local original=game.DestroyClientUIControl
game.DestroyClientUIControl=function(c)calls=calls+1;original(c)end
for _,c in ipairs(controls)do original(c)end;rawset(host,'alive',false);a:onEngineDestroy();a:onEngineDestroy()
assert(calls==0 and LiveCount()==0 and a:status().phase=='destroyed');assert(not a:begin());assert(not a:tick(g));assert(a:release());assert(calls==0)
`));
test('template zero, wrong source, malformed batch and dead host fail closed',()=>withVm(`
for _,b in ipairs({0,-1,1.5,math.huge})do assert(not pcall(Adapter.new,host,data,{imagePrefabId=1234,batchSize=b}))end
local bad={sourceSha256='wrong',width=480,height=270,rows=data.rows,root=data.root};assert(not pcall(Adapter.new,host,bad,{imagePrefabId=1234}))
a=Adapter.new(host,data,{imagePrefabId=0,batchSize=4});assert(not a:begin());assert(#controls==0)
rawset(host,'alive',false);assert(not a:retry());assert(#controls==0)
`));
test('engine-destroy tombstone prevents same still-reported-alive host from resurrecting',()=>withVm(`
a=New(2);a:begin();a:onEngineDestroy();local again=New(2)
assert(again==a,'engine-destroyed host identity was forgotten');assert(not again:begin());assert(#controls==0)
`));
test('host death before the next tick retires the job rather than leaving it pending',()=>withVm(`
a=New(2);local _,g=a:begin();rawset(host,'alive',false);assert(not a:tick(g))
assert(a:status().phase=='destroyed','dead host left a pending update job');assert(#controls==0)
`));
test('explicit false destroy result is retained as failure, not silently dropped',()=>withVm(`
a=New(2);a:begin();a:tick(a:status().generation);local original=game.DestroyClientUIControl
game.DestroyClientUIControl=function(c)if c==controls[1]then return false end;return original(c)end
assert(not a:release(),'false native destroy was accepted');assert(LiveCount()==1 and a:status().retained==1)
game.DestroyClientUIControl=original;assert(a:release());assert(LiveCount()==0)
`));
test('creation is rejected while cleanup callbacks reenter and host configuration failure latches',()=>withVm(`
a=New(2);a:begin();a:tick(a:status().generation);local original=game.DestroyClientUIControl
game.DestroyClientUIControl=function(c)assert(not a:begin());assert(not a:tick(a:status().generation));return original(c)end
assert(a:release());assert(LiveCount()==0)
local set=host.SetSizeDelta;host.SetSizeDelta=function()return false end;assert(not a:begin());assert(a:status().phase=='failed');assert(LiveCount()==0)
host.SetSizeDelta=set;assert(a:retry());a:tick(a:status().generation);assert(LiveCount()==2);a:release()
`));

test('packaged data module is exactly the hash-locked original literal block',()=>{assert(fs.existsSync(DATA_FILE),'data wrapper is not prepared');assert.equal(fs.readFileSync(DATA_FILE,'utf8'),dataSource);});
test('active release guards host hide reentry before begin/tick or nested release',()=>withVm(`
a=New(2);a:begin();a:tick(a:status().generation);local set=host.SetVisible;local callbacks=0
host.SetVisible=function(self,value)
 if not value then
  callbacks=callbacks+1;assert(callbacks==1,'release recursively hid host')
  assert(not a:begin(),'host setter resurrected cancelled build');assert(not a:tick(a:status().generation));a:release()
 end
 return set(self,value)
end
assert(a:release());assert(callbacks==1 and a:status().phase=='released' and LiveCount()==0 and not host.visible)
`));
test('explicit false host hide is reported as release failure while cleanup still runs',()=>withVm(`
a=New(2);a:begin();a:tick(a:status().generation);local set=host.SetVisible
host.SetVisible=function()return false end
assert(not a:release(),'host hide rejection was falsely accepted');assert(LiveCount()==0)
host.SetVisible=set;assert(a:release());assert(a:status().phase=='released')
`));
