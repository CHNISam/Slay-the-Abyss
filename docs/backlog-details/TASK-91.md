# TASK-91 排序文案短修

基线 `origin/develop@7adc71b6`。仅改卡组浏览排序标签和现有 `pageHint` 文案，不改 `projectCards`、`costRank`、过滤器、牌堆投影或命令。

- 卡组初始顺序保留本局牌组排列；牌堆初始顺序保留打开时既有展示（冰冻之眼等原有展示规则不变）。
- 费用升序：数值费用→X费→不可打出；类型：攻击→技能→能力→状态→诅咒。同值保留初始顺序。
- 非手柄浏览复用底部 640×40、14 字号的单行提示，最长25个字符（含标点），按全角保守估算350逻辑单位；不新增控件或移动布局。手柄原导航提示保留。

2026-10-31 本地 Node v22.22.1：重新 `build:data` / `build:ui` 后，`node --test tests/deck-browse-filters.test.mjs tests/deck-ui-layout.test.mjs tests/deck-browse-source-inverse.test.mjs` 7/7 通过。包含四组真实 Lua 浏览回归、费用与类型结果/标签、初始顺序/牌堆提示、过滤与 Run 不变、布局和冻结历史合同。`git diff --check` 通过。

首次运行因沙箱禁止子进程、未生成本树主题而失败；生成本树数据/UI并在授权子进程环境重新运行后通过，未放宽测试。没有完整 CI、候选、官方导入或设备实测；任务保留 In Progress，交主控独立复审与集成。
