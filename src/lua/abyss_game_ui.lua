-- Host for the same-run map, node and battle controllers. Only commands change rules.
require("abyss_run")
require("abyss_map")
local Nodes = require("abyss_nodes")
local BattleUI = require("abyss_battle_ui")
local MapUI = require("abyss_map_ui")
local NodeUI = require("abyss_node_ui")
local DeckUI = require("abyss_deck_ui")
local PotionDiscardUI = require("abyss_potion_discard_ui")
require("abyss_narrative")
local Bgm = require("abyss_bgm")
local CharacterSelect = require("abyss_character_select")
require("abyss_character_select_view")
local Controller = require("abyss_controller")
local MenuView=require("abyss_game_ui_menu_view")
require("abyss_theme")
local M = {}
require("abyss_numbers")
require("abyss_run_seed")
local NeowHistory=require('abyss_neow_history')
local EndingHistory=require('abyss_ending_history')
require('abyss_acts')
local VictoryEgg=require('abyss_victory_easter_egg')

local Overlays = require('abyss_game_ui_overlays')
local View = require('abyss_game_ui_view')
local RunFlow = require('abyss_game_ui_run')
local Lifecycle = require('abyss_game_ui_lifecycle')
local Input = require('abyss_game_ui_input')

function M.new(root, data, presentation, clickEvent, platform)
    -- A seed is an explicit replay/test override. Normal runs sample at Start,
    -- never while constructing the title screen or refreshing the UI.
    local self = { root = root, data = data, seed = platform.seed, mode = "menu" }
    local neowHistory=NeowHistory.new(platform.readNeowHistory)
    local endingHistory=EndingHistory.new({read=platform.readEndingHistory,write=platform.writeEndingHistory})
    local controller = Controller.new(platform.controllerApi,root)
    -- Read-only Production data service; no navigation or eager catalogue build.
    self.productionCompendium = Overlays.productionCompendium(data,presentation)
    self.controller = controller
    platform.controller = controller
    local newSeed = platform.newSeed or function() return require("abyss_new_run_seed").next() end
    local bgm = Bgm.new(platform.music)
    local function child(name) return assert(root:GetChild(name), "missing game panel " .. name) end
    local menu = child("menuPanel")
    local exitPanel, exitEntry = child("exitPanel"), child("exitEntry")
    local runMenu = child("runMenu")
    local owner = {exitGeneration=0, menuGeneration=0, ready=false}
    local characterPanel = child("characterPanel")
    self.characterSelection=CharacterSelect.new(data,presentation,platform.campaignProfile or platform.characterProfile)
    self.fastMode=false
    self.setFastMode = Overlays.setFastMode(self)
    local openingCovered = Overlays.openingCovered(self)
    local canViewRoute = Overlays.canViewRoute(self,openingCovered)
    local changed = Overlays.changed(self,owner)
    self.battleUI = BattleUI.new(child("battlePanel"), data, presentation, clickEvent,
        platform, { embedded = true, onChange = changed, onPile=function(kind)return self:openDeck(kind)end })
    self.mapUI = MapUI.new(child("mapPanel"), nil, function(node)
        if self.disabled or not self.run or self.mode ~= "map" or self.deckUI and self.deckUI.visible then return false, "not_on_map" end
        local ok, reason = Nodes.enter(self.run, self.map, node.id)
        if ok then changed() end
        return ok, reason
    end, clickEvent, { embedded = true, color = platform.color, imageSource = platform.imageSource,
        cursor = platform.cursorEvents, controller = controller,
        available=function(map)return Nodes.available(self.run,map)end })
    self.nodeUI = NodeUI.new(child("nodePanel"), nil, nil,
        presentation, clickEvent, changed, { color = platform.color, imageSource = platform.imageSource,
            imageTypes = platform.imageTypes,
            cursorEvents = platform.cursorEvents, sound = platform.sound, controller = controller, touchScreen = platform.touchScreen,
            enhancedRooms=true,
            onInspectCard=function(definition,upgraded)
                if not self.run or self.disabled or self.mode~='node' or self.exitOpen
                    or self.deckUI.visible or self.potionUI.visible or self.settlementRequested then return false end
                if not self.deckUI:inspect(self.run,definition,upgraded) then return false end
                self:refresh();return true
            end })
    self.deckUI = DeckUI.new(child("deckPanel"), presentation, clickEvent, platform, function() return self:closeDeck() end)
    do
        self.choiceUI = require("abyss_choice_ui").new(child("choicePanel"),presentation,clickEvent,platform,
            function(kind,uids,token,generation,battle)
                return self.battleUI:chooseCards(kind,uids,token,generation,battle)
            end)
    end
    local inCombat = Overlays.inCombat(self)
    local canManagePotions = Overlays.canManagePotions(openingCovered,self)
    local resourceHint = Overlays.resourceHint(self,canManagePotions,inCombat)
    self.relicUI=require('abyss_relic_view_ui').new(child('relicPanel'),child('relicBar'),clickEvent,platform,
        function(run,id)return self.nodeUI:describeRelic(run,id)end,function()return self:closeDeck()end,
        function(i)return self:openRelics(i)end,function()return self.mode end)
    self.potionUI=PotionDiscardUI.new(child("potionPanel"),clickEvent,platform,canManagePotions,changed,
        function()return self:closePotions()end)
    self.openPotions = Overlays.openPotions(self)
    self.closePotions = Overlays.closePotions(self)
    local prologuePanel = root:GetChild("prologuePanel")
    -- The cinematic camera and its skip control were cancelled. Keep the panel
    -- hidden so it cannot mask Neow or leave an old click target.
    self.prologue=nil
    if prologuePanel then prologuePanel:SetVisible(false) end

    self.openExit = Overlays.openExit(self,owner)
    self.openMenu = Overlays.openMenu(self,owner)
    self.closeExit = Overlays.closeExit(self,exitPanel,owner)
    self.confirmExit = Overlays.confirmExit(self,owner)

    self.openDeck = Overlays.openDeck(openingCovered,self)
    -- TASK-4.7 owned relics: icon-disc slots, not a text dump. Opening rides
    -- the deck gate so it stays read-only for battle, map, camp and chest.
    self.openRelics = Overlays.openRelics(self)
    self.closeDeck = Overlays.closeDeck(self)

    local menuView = MenuView.new(self,menu,data,platform)
    if root:GetChild('victoryEasterEgg') then
        self.easterEgg=VictoryEgg.new(root,{canOpen=function()
            return type(platform.createEasterEggArt)=='function' and self.mode=='victory' and not self.disabled
                and not self.characterOpen and not self.exitOpen and not self.settlementRequested and not self.settlementBusy and not self.motion.deathReveal
        end,createArt=platform.createEasterEggArt,onVisibility=function(value)
            self.easterEggOpen=value;owner.exitGeneration=owner.exitGeneration+1;owner.menuGeneration=owner.menuGeneration+1;self:refresh()
        end})
    end
    self.onEngineDestroy = Lifecycle.onEngineDestroy(self)
    local start,settlement=menuView.start,menuView.settlement
    local present = View.present(menuView)
    self.animate = View.animate(menuView)
    local menuLoading,characterLoading,originalCharacterHint=false,false,nil
    self.paintArtLoading = View.paintArtLoading(platform,menu,self,menuLoading,characterPanel,characterLoading,originalCharacterHint)

    self.syncController = View.syncController(self,controller,openingCovered)
    local finishRunFlow = View.finishRunFlow(neowHistory,endingHistory,self)
    local selectMode = View.selectMode(self)
    local syncMenuContext = View.syncMenuContext(self,owner)
    local syncCardChoice = View.syncCardChoice(self)
    local closeStaleDeck = View.closeStaleDeck(self)
    local openCardChoice = View.openCardChoice(self)
    local syncRewardReturn = View.syncRewardReturn(self)
    local refreshPotionEntry = View.refreshPotionEntry(child,inCombat,canManagePotions,platform)
    local refreshDeckEntry = View.refreshDeckEntry(child,self)
    local refreshUtilities = View.refreshUtilities(child,self,inCombat,refreshPotionEntry,refreshDeckEntry)
    local refreshMapResources = View.refreshMapResources(child)
    local suspendBattle = View.suspendBattle(self,openingCovered)
    local refreshPageVisibility = View.refreshPageVisibility(menu,self,suspendBattle,child,refreshMapResources)
    local renderBattlePage = View.renderBattlePage(self,child)
    local updateBossEntrance = View.updateBossEntrance(self,child)
    local renderMapPage = View.renderMapPage(self)
    local renderCurrentPage = View.renderCurrentPage(self,renderBattlePage,renderMapPage)
    local exitDialogOwnsForeground = View.exitDialogOwnsForeground(self)
    local refreshExitDialog = View.refreshExitDialog(exitDialogOwnsForeground,exitPanel,self)
    local syncPortraits = View.syncPortraits(platform,self)
    local exitEntryVisible = View.exitEntryVisible(self)
    local refreshForeground = View.refreshForeground(characterPanel,self,platform,exitEntry,exitEntryVisible,exitPanel,exitDialogOwnsForeground,runMenu,canViewRoute,child,refreshExitDialog)
    local overlaysBlocked = View.overlaysBlocked(self)
    local syncOpening = View.syncOpening(self,openingCovered)
    local openingForeground = View.openingForeground(self,child,prologuePanel,runMenu,exitPanel)
    local syncOfficialBattleScene = View.syncOfficialBattleScene(root,self)
    self.refresh = View.refresh(self,finishRunFlow,syncOpening,selectMode,syncOfficialBattleScene,syncMenuContext,platform,syncCardChoice,closeStaleDeck,openCardChoice,canManagePotions,overlaysBlocked,syncRewardReturn,refreshUtilities,refreshPageVisibility,renderCurrentPage,bgm,present,refreshForeground,syncPortraits,openingForeground)
    local selectionChanged = RunFlow.selectionChanged(self,owner)
    self.closeCharacters = RunFlow.closeCharacters(self,selectionChanged)
    self.selectCharacter = RunFlow.selectCharacter(self,selectionChanged)
    self.selectElement = RunFlow.selectElement(self,selectionChanged)
    self.start = RunFlow.start(self,selectionChanged)
    local beginRun = RunFlow.beginRun(platform,data,self,newSeed,presentation,endingHistory,neowHistory,prologuePanel,owner)
    self.confirmCharacter = RunFlow.confirmCharacter(self,beginRun)
    self.advanceAct = RunFlow.advanceAct(self)
    self.settle = RunFlow.settle(self,owner)
    owner.requestSettlement = RunFlow.requestSettlement(self,platform,neowHistory,owner)
    self.resize = Lifecycle.resize(self,owner)
    self.update = Lifecycle.update(self,controller,platform,openingCovered,updateBossEntrance,bgm)
    self.disable = Lifecycle.disable(self,platform,controller,characterPanel,owner)
    local dismissFromOutside = Input.installUtilities(self,child,clickEvent,controller,inCombat,exitPanel,runMenu)
    local bindCommand = Input.bindCommand(platform,self,canManagePotions,controller,clickEvent,owner)
    Input.installMenu(self,child,clickEvent,resourceHint,bindCommand,start,settlement,exitEntry,exitPanel)
    Input.installGuide(self,exitPanel,clickEvent,bindCommand,dismissFromOutside,runMenu,canViewRoute,child,owner)
    Input.installCharacters(self,characterPanel,clickEvent,bindCommand,selectionChanged,controller)
    owner.ready = true
    if controller then
        controller.beforeAction=function()self.battleUI:cancelControllerPointers()end
        controller.onChange=function()self:syncController()end
    end
    self:refresh()
    self:syncController()
    return self
end
return M
