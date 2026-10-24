-- Visual fixture only. Never deploy through the production manifest.
local M={}
local Run,Combat=require('abyss_run'),require('abyss_combat')
function M.new(view,data,stage)
    local self={elapsed=0,index=0,done=false}
    local values={1,10,99,100,999,100}
    local function show(index)
        local count=index==6 and 1 or 5
        local enemies={}
        for i=1,count do enemies[i]=index==6 and 'guardian' or 'cultist' end
        local run=Run.new(data,41)
        assert(Run.startCombat(run,'cultist_solo'))
        local deck={}
        for i=1,25 do deck[i]=i%2==0 and 'defend' or 'strike' end
        local battle=Combat.new(data,{seed=41,hp=79,deck=deck,enemies=enemies})
        battle.player.block=values[index]
        battle.player.statuses={strength=10,weak=10,vulnerable=10}
        for _,enemy in ipairs(battle.enemies) do
            enemy.block=values[index]
            enemy.statuses={strength=10,weak=10,vulnerable=10}
        end
        for i=1,10 do battle.discard[#battle.discard+1]=table.remove(battle.draw) end
        run.combat,run.hp=battle,battle.player.hp
        if view.battleUI.feedback then view.battleUI.feedback:cancel() end
        view.run,view.battleUI.run,view.nodeUI.run=run,run,run
        local ui=view.battleUI
        ui.busy,ui.displayBattle,ui.info,ui.help,ui.selected,ui.target=false,nil,nil,nil,nil,1
        view:refresh();ui:render()
        stage:GetChild('battlePanel'):GetChild('notice').text='数字验收夹具 · 非自然战斗 · 格挡 '..values[index]
        print('M3_NUMERIC case='..index..' block='..values[index]..' enemies='..count..' fixture=true')
    end
    function self:update(dt)
        if self.done then return end
        self.elapsed=self.elapsed+dt
        local index=math.floor(self.elapsed/8)+1
        if index>6 then
            self.done=true
            print('M3_NUMERIC complete cases=6 fixture=true')
            assert(view:openExit());assert(view:confirmExit())
        elseif index~=self.index then self.index=index;show(index) end
    end
    return self
end
return M
