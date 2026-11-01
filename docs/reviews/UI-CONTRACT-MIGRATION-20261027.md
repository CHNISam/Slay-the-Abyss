# 活怪显示槽的测试合同迁移

基于冻结`f1a0b02`，两个原wrapper均先在未修改的独立树复现失败：53个战斗用例的第33例在`battle_ui_cases.lua`死亡断言失败；真实Host流程在`game_ui_fixture.lua`点击隐藏`enemy2`失败。前者把死怪原数组位置当成必须隐藏的屏幕槽，后者把核心目标下标直接拼成控件名。

本切片只改测试。毒伤用例保留毒伤/死亡/存活敌人行动各一次的断言，并增加真实死怪HP为0、存活cultist生命为正、其名称和准确HP显示在`enemy1`、其余四个屏幕槽全部隐藏。后续荆棘来源和事件断言不变。Host的`win`仍通过真实点击完成战斗，只把真实actor下标经`EnemyView.slots`转换为屏幕槽，并核对actor引用和ID；点击隐藏控件的防护未删除。

53例冻结保护仍保留PR206的原SHA256 `d97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678`。wrapper要求精确的新断言块只出现一次、旧断言已不存在，再仅将这一个已审块逆归一化为原断言后核验原hash。这样明确记录合同变化，同时证明其余所有case body及中间helper逐字节未变；仍校验53个编号各执行一次，不改切片、时限、注册数或Lua运行入口。

迁移后串行运行`node --test tests/battle-ui-slices.test.mjs`和`node --test tests/game-ui.test.mjs`，前者1项、后者6项全部通过，零跳过。Lua仍使用原预算：53例按1–26/27–53切片各执行一次；Host wrapper中的原流程15例、牌组6例、序章10例全部执行。`git diff --check`通过。

没有生产、Backlog、静态基线或平台操作改动。本地wrapper结果只证明离线合同迁移，不构成实机验收。
