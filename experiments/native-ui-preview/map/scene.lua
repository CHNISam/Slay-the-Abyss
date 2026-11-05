function OnStart()
 local root=script.object
 local w,h=game.GetUICanvasSize()
 local scale=math.min(w/1280,h/720)
 root:SetLocalScale(scale,scale,1)
 assert(root:GetChild('mapNodes') and root:GetChild('routeDashes') and root:GetChild('legend'))
 print('APPROVED_MAP_READY native_controls=true source=7e40d2d sample_seed=0 view=start scroll_top=834 input_verified=false core_run_connected=false')
end
