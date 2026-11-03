package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
assert(package.loaded.abyss_combat==nil)
local previous=package.preload.abyss_combat
package.preload.abyss_combat=function()error('COPY_ONLY_INITIALIZATION_LOADED_COMBAT')end
local ok,Initialization=pcall(require,'abyss_run_initialization')
package.preload.abyss_combat=previous
assert(ok,Initialization)
assert(package.loaded.abyss_combat==nil)
local Copy=require('abyss_copy')
local Data=require('abyss_data')
local Run={}
Initialization.install(Run,{preparedCharacters={ironclad=true,silent=true,defect=true,watcher=true},
 preparedOriginalRoles={HT=true,AR=true,FR=true,RD=true}})
local source=Copy.copy(Data)
local probe={value=41};probe.self=probe
source.rules.player.startingRelics.copyProbe=probe
source.rules.player.startingRelics.copyAlias=probe
local first=Run.new(source,29)
local second=Run.new(source,29)
assert(first.relics~=source.rules.player.startingRelics and first.relics~=second.relics)
assert(first.relics.copyProbe==first.relics.copyAlias)
assert(first.relics.copyProbe.self==first.relics.copyProbe)
assert(first.relics.copyProbe~=probe and first.relics.copyProbe~=first.data.rules.player.startingRelics.copyProbe)
first.relics.copyProbe.value=99
assert(probe.value==41 and second.relics.copyProbe.value==41)
assert(first.data.rules.player.startingRelics.copyProbe.value==41)
local failed,reason=pcall(Run.new,source,29,{campaign=true})
assert(not failed and tostring(reason):find('campaign requires explicit experimental mode',1,true))
assert(probe.value==41 and probe.self==probe and source.rules.player.startingRelics.copyAlias==probe)
local failure={marker='copy_failure'}
local bad=Copy.copy(Data)
bad.rules.player.startingRelics.copyProbe=setmetatable({}, {__pairs=function()error(failure)end})
local success,err=pcall(Run.new,bad,29)
assert(not success and err==failure)
assert(getmetatable(bad.rules.player.startingRelics.copyProbe)~=nil)
print('RUN_INITIALIZATION_COPY_PASS cold load, graph isolation, input and error identity')
