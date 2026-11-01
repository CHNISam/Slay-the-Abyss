package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local Run,C,D=require('abyss_run'),require('abyss_combat'),require('abyss_data')
local function strike(data)for _,c in ipairs(data.cards.cards)do if c.id=='strike'then return c end end;error('strike')end
local source=C.copy(D);strike(source).effects[1].value=123
-- Selected native input is authoritative; a foreign rule mismatch is refused.
assert(strike(Run.new(source,42).data).effects[1].value==123)
assert(strike(Run.new(source,42,{character='ironclad',experimental=true}).data).effects[1].value==123)
for _,id in ipairs({'silent','defect','watcher'})do
 local ok,err=pcall(Run.new,source,42,{character=id,experimental=true})
 assert(not ok and tostring(err):find('incompatible caller foreign card: strike',1,true),'foreign red rules must reject for '..id)
end
assert(strike(source).effects[1].value==123,'refusal never changes caller input')
print('RUN_CARD_CATALOG_REVIEW_RED_FOREIGN_PASS selected native current value retained and incompatible red foreign rule rejected for all other classes')
