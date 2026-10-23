# 岩脉残响接入计划 · TASK-32

目标：沿用用户批准素材，让进入遗迹、守卫身份和胜败有简短的解释。

设计：保留 PR19 主题和全部现有控件。菜单 summary 用短版背景加操作说明；结算 summary 增加一行旁白，保留四行统计和错误提示。Boss 进入时复用 battlePanel.notice，仅设置一次，后续操作提示优先。节点 notice 在主视图组合风味和原操作说明，错误、成功提示及升级/删牌子页面优先。

技术：JSON → 既有 build:ui 的 toLua → abyss_narrative，供现有 Lua 展示层读取。没有新剧情状态或规则。素材原文位于 data/presentation/narrative.zh-CN.json，其余原包保留在 docs/lore/source；这是本作原创局部设定。

1. 扩展现有 game_ui/node_ui 集成测试，先验证新增文本缺失会失败；保留真实规则命令、胜败、重开和正式结算回归。
2. 接入构建产物及三个现有展示控制器；只用 compact，不改控件、字号和规则。
3. 按最坏每字一字号、原生 lineHeight=40 核算容量，检查主菜单、错误结算和节点最长组合；记录本地实际输出。运行 npm run check 与 diff 检查。
4. PR 当前 SHA Quality 全绿后审查并 squash 集成。平台导入、真实文字裁切、鼠标/手机试玩保持未验，由现有 TASK-3/5/10.1.2/12.3 等关口收集证据，不阻塞 M1。
