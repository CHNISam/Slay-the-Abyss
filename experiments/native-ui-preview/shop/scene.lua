function OnStart()
 script:EnableUpdate(true)
 Navigation={}
 Controller=NewShopController(script.object,{onNavigate=function(target,data)Navigation[#Navigation+1]={target=target,data=data};print('SHOP_NAVIGATE target='..target..' gold='..data.gold)end})

 print('SHOP_INTERACTIVE_READY scenario=normal input_verified=false production_rules=false')
end
function OnUpdate(dt)if Controller then Controller:tick(dt)end end
function OnDestroy()if Controller then Controller:destroy()end end
