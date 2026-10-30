-- Resolve real native instances in source display order. Controls are owned by
-- stable actor IDs; an absent actor has no hidden, fixed enemyN placeholder.
local Surfaces=require('abyss_monster_surfaces')
return function(panel,name)
    local index=assert(tonumber(name:match('^enemy(%d+)$')),'expected enemy display index')
    local manager=assert(Surfaces.get(panel),'missing native monster manager')
    local rows={}
    manager:each(function(box,slot,entry)
        if box.visible then rows[#rows+1]={box=box,slot=slot,entry=entry} end
    end)
    table.sort(rows,function(a,b)return a.entry.index<b.entry.index end)
    local row=rows[index]
    if row then return row.box,row.slot,row.entry end
end
