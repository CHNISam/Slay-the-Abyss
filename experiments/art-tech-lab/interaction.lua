-- Isolated art probe. Uses real card definitions at build time; does not replace combat.
local cards = {}
local selected = 0
function OnStart()
  script.object.showCursor = true
  for i = 1, 3 do
    local index = i
    cards[i] = script.object:GetChild('card' .. i)
    cards[i]:GetChild('hit'):AddCursorEventListener(Enum.CursorEventType.CursorClick, function()
      if selected == index then
        cards[index]:SetVisible(false)
        selected = 0
        print('art-probe-play:' .. index)
      else
        for j=1,3 do
          cards[j]:SetLocalScale(1,1,1)
          cards[j]:SetAnchoredPosition(-230+(j-1)*230,-263)
        end
        cards[index]:SetLocalScale(1.2,1.2,1)
        cards[index]:SetAnchoredPosition(-230+(index-1)*230,-215)
        selected = index
        print('art-probe-select:' .. index)
      end
    end)
  end
  print('art-probe-ready')
end
