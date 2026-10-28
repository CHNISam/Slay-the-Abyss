-- Existing action suites still exercise the real native button sequence. Only
-- the approved explicit Use step is added; raw emit() remains raw for stale input.
return function(ui,panel,touch,previousAim)
 local token=ui.potionMenu
 if not token or previousAim and previousAim.slot==token.slot then return end
 local use=panel:GetChild('potionHelp'):GetChild('potionPopup'):GetChild('use')
 if not use.interactable then return end
 local event={touchId=touch}
 if use.listeners.down then use.listeners.down(event);use.listeners.up(event)end
 return use.click(event)
end
