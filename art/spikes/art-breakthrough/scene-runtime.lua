-- 杀戮原塔2 美术突破实验：低多边形英雄 + 精装卡牌手牌（千星奇域客户端 Lua）
-- 挂到服务端控件模板的根容器(或专用空容器)；需客户端控件模板：IMG(图片) TXT(文本框) BOX(空容器)
-- 每个三角面 = 1 个图片控件(静态图 100003) + 尺寸 + 旋转Z + 单轴X/Y正交压缩(少数为X+Y混合)。
local IMG_PREFAB = 0   -- @@IMG@@ 客户端图片控件模板索引
local TXT_PREFAB = 0   -- @@TXT@@ 客户端文本框模板索引
local BOX_PREFAB = 0   -- @@BOX@@ 客户端空容器模板索引
--@@DATA@@

local H_ALIGN = { Left = 0, Middle = 1, Right = 2 }
local function draw(parent, r)
  if r[1] == "T" then
    local t = game.InstantiateClientUIControl(TXT_PREFAB, parent)
    if t == nil then return end
    t:SetAnchorMin(0.5, 0.5); t:SetAnchorMax(0.5, 0.5); t:SetPivot(0.5, 0.5)
    t:SetSizeDelta(r[4], r[5]); t:SetAnchoredPosition(r[2], r[3])
    t.text = r[6]; t.fontSize = r[7]
    t.fontColor = Color.FromRGBA(r[8], r[9], r[10], 255)
    if r[11] == 1 then t.enableOutline = true; t.outlineColor = Color.FromRGBA(r[12], r[13], r[14], 255) end
    pcall(function() t.horizontalAlignment = Enum.TextHorizontalAlignment[r[15]] end)
    pcall(function() t.verticalAlignment = Enum.TextVerticalAlignment.Middle end)
    return t
  end
  local c = game.InstantiateClientUIControl(IMG_PREFAB, parent)
  if c == nil then return end
  c:SetAnchorMin(0.5, 0.5); c:SetAnchorMax(0.5, 0.5); c:SetPivot(0.5, 0.5)
  c:SetImage(Enum.ImageSource.StaticReference, r[1])
  pcall(function() c.imageType = Enum.ImageType.Stretch end)
  c.imageColor = Color.FromRGBA(r[9], r[10], r[11], r[12])
  c:SetSizeDelta(r[4], r[5])
  if r[6] ~= 0 or r[7] ~= 0 or r[8] ~= 0 then c:SetLocalRotation(r[6], r[7], r[8]) end
  c:SetAnchoredPosition(r[2], r[3])
  return c
end

local boxes = {}
local function build(root, name)
  local box = game.InstantiateClientUIControl(BOX_PREFAB, root)
  box:SetAnchorMin(0.5, 0.5); box:SetAnchorMax(0.5, 0.5); box:SetPivot(0.5, 0.5); box:SetSizeDelta(1, 1)
  local p = GROUP_POS[name]; box:SetAnchoredPosition(p[1], p[2])
  for _, r in ipairs(GROUPS[name]) do draw(box, r) end
  boxes[name] = box
  return box
end

-- hand layout: whole card moves/scales as ONE container (no per-triangle updates)
local HAND = { "card1", "card2", "card3", "card4", "card5" }
local BASE_S, SEL_S = 0.62, 0.95
local cur = {}
local selected = 0
local t = 0
local function target(i)
  local off = i - 3
  if i == selected then return off * 128, -130 + 0 - math.abs(off) * 10, SEL_S, 0 end
  return off * 128, -250 - math.abs(off) * 10, BASE_S, -off * 3
end

function OnStart()
  local root = script.object
  for _, n in ipairs({ "bg", "hero", "panel" }) do build(root, n) end
  for i, n in ipairs(HAND) do
    build(root, n)
    local x, y, s, r = target(i); cur[i] = { x, y, s, r }
    boxes[n]:SetAnchoredPosition(x, y); boxes[n]:SetLocalScale(s, s); boxes[n]:SetLocalRotation(0, 0, r)
  end
  script:EnableUpdate(true)
  print("STA art scene built")
end

-- demo autoplay: select cards 1..5 in turn (1.2s each), eased move/scale
function OnUpdate(dt)
  t = t + (dt or 1 / 30)
  local want = math.floor(t / 1.2) % 6   -- 0 = none selected
  if want ~= selected then
    selected = want
    if selected > 0 then boxes[HAND[selected]]:SetAsLastSibling() end
  end
  local k = math.min(1, (dt or 1 / 30) * 12)
  for i, n in ipairs(HAND) do
    local x, y, s, r = target(i)
    local c = cur[i]
    c[1] = c[1] + (x - c[1]) * k; c[2] = c[2] + (y - c[2]) * k; c[3] = c[3] + (s - c[3]) * k; c[4] = c[4] + (r - c[4]) * k
    boxes[n]:SetAnchoredPosition(c[1], c[2]); boxes[n]:SetLocalScale(c[3], c[3]); boxes[n]:SetLocalRotation(0, 0, c[4])
  end
end
