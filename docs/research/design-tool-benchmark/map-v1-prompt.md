你现在担任一名资深游戏 UI/UX 艺术总监、交互设计师和前端原型工程师。

我要测试你的真实游戏界面设计能力。请为我正在开发的《杀戮原塔2》（Slay the Abyss）重新设计**游戏内的爬塔路线地图页**，并直接制作可运行的高保真交互原型。

## 1. 读取真实项目

公开 GitHub 仓库：\
[https://github.com/CHNISam/Slay-the-Abyss](https://github.com/CHNISam/Slay-the-Abyss)

工作基线：最新 `develop` 分支。

优先阅读：

- `AGENTS.md`
- `docs/design/ui-canvas/README.md`
- `docs/design/ui-canvas/Map.dc.html`
- `docs/design/UI_DESIGN.md`
- `docs/design/MAP_IMPLEMENTATION.md`
- `docs/design/screens/map.png`
- `src/lua/abyss_map_ui.lua`
- `data/presentation/ui_theme.json`
- `.codebuddy/skills/miliastra-wonderland/SKILL.md`

注意：旧设计稿与后续修订可能冲突，以最新明确决定为准。

请实际阅读文件，不要仅凭 README 猜测当前实现。如果访问失败，明确说明无法访问哪些文件。

## 2. 设计目标

游戏运行在《原神》的千星奇域平台，玩法参考《杀戮尖塔》。

地图不是现实世界地图，而是具有多条分叉路线、房间节点和层数进度的 Roguelike 爬塔地图。

美术目标：

- 保留《杀戮尖塔》原版地图的冒险感、神秘感、粗粝质感与路线探索氛围。
- 融入《原神》璃月、岩元素、古代遗迹与地脉侵蚀的视觉语言。
- 让地图拥有鲜明的世界观和高级游戏美术质感，而不是普通网页、后台管理系统或通用游戏模板。
- 特别重视地图背景、路线纹理、节点图标、留白、层次、字体、动态反馈与整体构图。

你有充分的艺术设计自主权，不需要机械复刻现有画面。但必须保留真实的游戏语义与核心交互。

## 3. 必须尊重的游戏约束

- 保留原项目的分支路线、15 层结构和节点可达性逻辑。
- 保留战斗、精英、事件、商店、营地、宝箱、首领等七类节点。
- 当前所在位置使用明确的角色令牌识别。
- 区分已走过、当前位置、可前往与不可达。
- 不给每个节点额外添加统一的外圈、光圈或背景圆盘。
- 右侧保留节点类型图例，不恢复已废弃的冗余状态说明和导航按钮。
- 顶部玩家资源、药水、牌组、菜单需要与现有游戏设计统一。
- 优先复用千星奇域官方图标与现有素材，营地使用风格统一的篝火图标。
- 不修改核心地图生成规则，不虚构新玩法。

设计基准为 1280×720，并考虑 PC、移动端宽屏和触屏安全区。

## 4. Skills 与工作方法

请尝试阅读并吸收以下公开设计 Skills：

**Frontend Design**\
[https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md](https://github.com/anthropics/skills/blob/main/skills/frontend-design/SKILL.md)

**Anti-Slop Design**\
[https://github.com/mervinj3546/anti-slop-design/blob/main/SKILL.md](https://github.com/mervinj3546/anti-slop-design/blob/main/SKILL.md)

**千星奇域开发 Skill**\
本项目 `.codebuddy/skills/miliastra-wonderland/SKILL.md`

把它们作为设计方法、反模板化审查和技术约束参考。如果无法加载某项 Skill，直接说明，不要假装已经执行。

采用视觉迭代方法：

设计 → 实现 → 运行预览 → 截图检查 → 视觉批评 → 改进。

重点提高设计品位，而不是通过堆叠装饰、光效或复杂动画制造虚假的精致感。

## 5. 实际交付

不要停留在文字建议，也不要只生成一张静态概念图。

请直接在 Google AI Studio Build 中创建一份**可运行的高保真 Web 交互原型**，可以使用 React、SVG、CSS 动画等技术。

必须可以实际体验：

1. 地图上下滚动、拖动查看路线。
2. 不同类型节点的点击、悬停、触屏反馈。
3. 当前节点、已访问节点、可前往节点和不可达节点的视觉区别。
4. 路线高亮、节点选择、切换状态的微动效。
5. 顶部 HUD、右上角菜单和节点图例的交互。
6. PC 与移动端的布局适配。

模拟数据必须符合真实项目规则；能复用真实地图数据就复用，不要用随机假图代替真实结构。

先产出**一套你认为最有竞争力的完整设计**，不要用三套低完成度方案敷衍。

完成后实际打开 Preview，检查视觉效果、响应式与交互，尽可能形成接近商业游戏正式版本的完成度。

设计质量以 9/10 为目标，但不要虚报分数。请明确指出尚未达到标准的地方，并针对主要问题迭代。

## 6. 边界

本轮是独立设计实验：

- 不直接修改原仓库的正式游戏代码。
- 不创建 PR，不提交或推送到原仓库。
- 不改变 Lua 地图业务逻辑。
- Web 原型可以模拟动效，但不能将 Web 效果等同于已在千星奇域原生平台实现。
- 后续移植必须考虑官方素材、Lua、原生 UI 控件及性能预算。

完成后给我可以直接操作的 Preview，并简要说明设计理念、使用了哪些 Skills、哪些效果能够移植到千星奇域。

**你的任务是拿出真正优秀的设计作品，让我直接通过交互原型判断你的游戏 UI/UX 审美能力。**
