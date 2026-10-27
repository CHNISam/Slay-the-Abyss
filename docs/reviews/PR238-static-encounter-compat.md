# PR238：静态遭遇完整状态参考构造兼容

基线 `28869011c26bcead7f925e78f00dbda454daa231`，独立分支 `test/pr238-static-encounter-compat`，保留原 UI 修复分支。只修改 `small_slimes.lua` 第 18 组的参考构造和本证据，不修改生产、Backlog、来源锁或预算。

## 原始 RED

CI rules4 记录第 18 组 full-state comparison 失败。本地在生产/原脚本未改时，以 ignored 临时副本仅选择该注册组，保留组内 16 个真实遭遇和原比较：status 1，2148 ms。

```text
not ok 1 - other 16 static encounter groups retain their member order and consume no misc selection draw: state.masterDeck.1: expected nil, got table
```

实际原始输出：本树 ignored `build/pr238-static-encounter-red.log`。临时 selector 不加入仓库，不更改组内正文/遍历；最终验收使用原脚本完整入口。

## 判断及最小迁移

当前 `Run.startCombat` 的真实构造（`abyss_run.lua` options 与 beforeFirstTurn）已传入 `masterDeck=run.deck`、当前 misc/card RNG、玩家 HP/maxHP/gold，以及药水 RNG/角色元数据。Core 对永久牌组和 RNG 复制私有状态，支持已实现的永久牌成长/升级归属。旧 reference 虽已使用 `run.data` 完整目录，仍缺这些等价入参，因此得到空 masterDeck；不应删除生产快照或从比较中略去它。

本片只将旧 reference 传参补齐。继续保留原 16 组列表/顺序、HP/AI/牌堆/完整 RNG/目录/所有 `same` 比较、misc 旧引用冻结、generation 唯一区别以及 `seen==16`。不使用小目录，也不抄入实际 battle 作为预期。

另外明确断言：Run 永久 deck 原值及每个原 table 引用不变；实际/参考 masterDeck 都是私有且逐字段等于永久 deck；两场战斗中的每张牌均通过 deckUid 唯一对应真实永久 UID、cardId 与升级状态，牌总数仍等于永久 deck。

## 原入口验收

完整 `tests/lua/small_slimes.lua` 实际在第11组后达到30000ms并超时，未作为GREEN。随后仅按原完整组分片：1–6、7–11、12–17、18，分别7634/9007/9409/21676ms全部通过。原18组与末组内16对完整构造均执行，默认30000ms不增。分片只改登记/输出编号，不改本迁移后的任何组正文；完整正文hash与覆盖门禁见PR238-CI-CLOSEOUT-20261027.md。
