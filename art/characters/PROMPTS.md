# 角色与开局美术 · 出图提示词规范

给出图 AI 用。每条提示词都可以直接粘贴使用，格式沿用 `art/cards/traveler-geo/*/prompt.txt`：
- 英文
- 先写参考图各管什么
- 再写构图
- 再写画风
- 最后写禁止项

出图后按 `art/processed/ai-samples/lumine` 的流程处理：先图元重绘，再做原生预览。不要直接把 PNG 放进运行时。

## 通用约束（每条都已写进提示词，不用另加）

- **读得出的标准**：成品会被图元重绘成 144×192（立绘）或 96×96（头像）。所以只追求三样东西：
  - 剪影大而清楚。
  - 3–4 个明暗大块。
  - 一处元素色光。

  不要追求细节。
- **背景**：近乎空的深色，带角色的元素色调。这样能和选角页的元素主题色衔接，背景色值见下表。
- **禁止**：文字、UI、边框、水印、Logo、多格拼图、多个角色、血腥、暴露尺度高于官方立绘。

| 资产 | 尺寸 | 背景主色 | 元素光 |
|---|---|---|---|
| 选角立绘 | 1536×2048（3:4） | 角色色 15% 混入 #0F1117 | 角色色 |
| 头像 | 1024×1024 | 同上 | 同上 |
| 七天神像 | 1536×2048 | #141A28 | 随角色元素换球体颜色，先出岩 #F0B850 |
| 旧路商人 | 1024×1024 | #2A1E18 暖褐 | 灯笼 #F0B850 |

角色色：

| 角色 | 色值 |
|---|---|
| 胡桃 | #E8743B |
| 阿蕾奇诺 | #D23A3A |
| 芙宁娜 | #4FA8E0 |
| 雷电将军 | #A77BE0 |
| 旅行者·岩 | #F0B850 |
| 旅行者·风 | #5FD3B6 |
| 旅行者·雷 | #B48CF0 |
| 旅行者·草 | #8FD14F |

---

## 1. 选角立绘（5 位 + 旅行者另 3 种元素）

### 共用段落（接在每位角色段落之后）

```
COMPOSITION: ONE character only, three-quarter view, framed from head to upper thigh, figure fills about 70% of the height, head in the upper third, slightly off-centre to the right so the left 30% stays calm for UI text. Clear silhouette against the background; the two or three costume shapes that identify the character must be readable at 144x192.
PAINTED LANGUAGE: polished anime key-art finish consistent with official Genshin Impact character art, but simplified into 3-4 large value groups with one strong element-coloured rim light from upper right. Matte, not glossy; no busy particle storm, at most a few large soft motes in the element colour.
BACKGROUND: almost empty deep dark field tinted toward {ELEMENT COLOUR}; one soft radial glow behind the shoulders in the same colour. No scenery, no architecture, no text.
ABSOLUTE AVOIDS: text, letters, numbers, UI, frame, border, logo, watermark, multiple panels, extra characters, chibi style, photorealism, gore, revealing outfit beyond the official design, cropped head, hands covering the face.
```

### 胡桃 · Hu Tao（火 #E8743B）
```
Hu Tao from Genshin Impact, the 77th Director of the Wangsheng Funeral Parlor. Identity carriers that MUST read: dark brown porkpie hat with a red plum-blossom sprig and a hanging talisman, very long dark brown twin tails reaching below the waist, dark brown Chinese-style long coat with tails and gold trim, red-flower pupils, playful smirk. Holds the Staff of Homa diagonally behind her (red-gold polearm head, upper right). A few small pale-orange spirit butterflies near the staff tip. Element colour {ELEMENT COLOUR}=#E8743B.
```

### 阿蕾奇诺 · Arlecchino（火 #D23A3A）
```
Arlecchino from Genshin Impact, the Fourth of the Fatui Harbingers, "The Knave". Identity carriers that MUST read: short white bob hair with black streaks, black X-shaped cross pupils, long black tailored coat with sharp tails, cool composed expression. A crimson crescent-moon-shaped scythe blade (her polearm) rises behind her shoulder at upper right, glowing faint red. Element colour {ELEMENT COLOUR}=#D23A3A.
```

### 芙宁娜 · Furina（水 #4FA8E0）
```
Furina from Genshin Impact, former Hydro Archon of Fontaine. Identity carriers that MUST read: small tilted dark-blue top hat, white hair with light-blue streaks and soft curls, heterochromatic blue eyes with water-drop highlights, dark blue and white tailcoat with short cape, theatrical confident pose with one hand raised like taking a bow. A thin rapier held low. A few large round water droplets float around her. Element colour {ELEMENT COLOUR}=#4FA8E0.
```

### 雷电将军 · Raiden Shogun（雷 #A77BE0）
```
Raiden Shogun from Genshin Impact, the Electro Archon of Inazuma. Identity carriers that MUST read: long dark purple hair in a single long braid, purple flower hair ornament on the left, violet eyes, purple kimono with wide hanging sleeves and a dark obi, calm solemn expression. Holds the Musou Isshin katana horizontally in front of her at chest height, blade edge faintly glowing violet. Element colour {ELEMENT COLOUR}=#A77BE0.
```

### 旅行者·荧 · Lumine（四种元素各一张）
```
Lumine, the female Traveler of Genshin Impact. Identity carriers that MUST read: short blonde hair with a long side lock, white cecilia flower hair ornament, golden eyes, white and gold sleeveless dress with long detached white sleeves and a flowing white scarf, gold diamond motifs on the belt, a one-handed straight sword held low. Element colour {ELEMENT COLOUR} = {VARIANT}.
VARIANTS (generate one image per line, same pose and framing so the four can swap in place):
- GEO #F0B850: amber angular rock fragments hover at the shoulder; rim light warm gold.
- ANEMO #5FD3B6: a single pale teal wind swirl wraps the scarf; rim light teal.
- ELECTRO #B48CF0: thin violet lightning arcs along the sword; rim light violet.
- DENDRO #8FD14F: a few green leaves and a small glowing seed of light near the hand; rim light leaf green.
```
已有 `art/source/lumine_geo_portrait.png` 可作为岩版本。另外三张要求姿势和构图都与它一致，这样切换元素时只换图、不跳位。

## 2. 选角头像（底部按钮用）

不用单独出图：直接从上面的立绘裁出头肩部分，取 1:1 正方形，头部占画面高度的 55%，再做图元重绘。
只有裁出来读不出脸时，才单独出图，提示词如下：

```
Head-and-shoulders portrait of {CHARACTER, same identity carriers as above}, square 1:1, face three-quarter view filling 55% of the frame height, hat/hair ornament fully inside the frame. Same painted language and element rim light as the key art. Plain dark background tinted toward {ELEMENT COLOUR}. No text, frame or border.
```

## 3. 七天神像（开局房间说话者）

```
Use case: stylized-concept. ONE original painted illustration, 3:4 portrait, of a Statue of The Seven from Genshin Impact: a seated, hooded goddess figure carved from pale weathered stone, one arm extended to the right holding a glowing elemental orb in its palm, sitting on a stepped stone pedestal. Faint teal moss in the cracks. The ORB is the only light source: GEO amber #F0B850, casting warm light on the statue's face and hand.
COMPOSITION: statue fills 80% of the height, slightly low angle, pedestal base cut by the lower edge, orb at about 62% width and 52% height. Dark empty cave-like background #141A28 with a soft glow around the orb only.
PAINTED LANGUAGE: same as the character key art; 3 value groups; stone surfaces broad and matte.
ABSOLUTE AVOIDS: text, UI, frame, real people, worshippers, scenery panorama, multiple statues, glowing eyes, horror mood.
```
需要换元素时只改球体颜色这一句：风 #5FD3B6、雷 #B48CF0、草 #8FD14F，其余不变。

## 4. 旧路商人（商店对话框头像）

身份依据：`docs/lore/v2/02-characters/MERCHANT.md`。商人是原创角色，不能用原神已有角色的造型。

```
Use case: stylized-concept. ONE original painted bust portrait, square 1:1, of an old travelling merchant who trades in ancient ruins: deep hood of a faded dark-grey blanket cloak, weathered tan face with a kind but shrewd half smile, short neat white beard, small round spectacles pushed up on the hood, a small brass lantern hanging at the lower right giving warm amber #F0B850 light on his cheek.
COMPOSITION: head and shoulders, face three-quarter left (looking toward the shop goods), face centre at 45% width and 45% height, must read inside a 108px circle crop.
PAINTED LANGUAGE: same family as the card art: broad painted planes, 3-4 value groups, warm lantern light vs cool shadow; background flat warm brown #2A1E18.
ABSOLUTE AVOIDS: any existing Genshin or Slay the Spire character design, mask, fantasy armour, text, frame, coins flying, extra people.
```

## 验收

每张图都要过以下四项：
1. **小尺寸可读**：缩到目标尺寸（144×192 或 96×96）后，靠剪影和标志物仍然认得出是谁。
2. **构图位置**：元素光在右上；左侧 30% 保持安静，留给文字。
3. **画风统一**：同一组图放在一起，画风一致；旅行者四张的姿势完全一致。
4. **提交内容**：交付时同时提交原图、实际用的提示词文本和 `asset.json`（SHA 和尺寸）。
