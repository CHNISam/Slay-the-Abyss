# PR193 容器上限修复候选

基线：386bc27ca892fda580a76bacdfd079817e8b40dc  
CI：[Quality 40123242940 / check 120959147533](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40123242940/job/120959147533)

## 根因
4 个 ERR_ASSERTION 是同一真实缺陷，不是超时：battleLayout.stage 有 61 个直接子控件，gameLayout 将其原样复制为 battlePanel，违反已有 60 上限。

develop f6712d0 为 59；PR 增加 rewardList / goldReward / cardReward、移除 skipPotion，净增 2。PR 前头 3dd00bb 为 60，同步新增 potionHelp 后达到 61。完整 gameLayout 只有 battlePanel 超限。

## 最小修复
补丁：candidate-result-group.patch。仅改 2 个生产文件和 4 个测试文件：
- ui-layout.mjs：把相邻 resultPlate / result 放入零偏移、整画布、focusable:false 的 resultGroup，无 hit 或输入拦截。
- abyss_battle_ui.lua：同步这两个控件的 child() 路径，保留药水说明路径及全部显示、配色逻辑。
- ui-layout.test.mjs / battle_ui.lua：新增结构与真实生成树回归。
- looter_feedback_ui.lua / looter_reward_stage.lua：仅更新已移动控件的读取路径，原业务断言保留。

全部原控件定义、坐标、尺寸、文本、颜色与绘制顺序逐项等价；battle / game 最大直接子控件数均为 60。没有删控件、放宽上限或延长测试时限。

## 验证
- 原 4 个失败门禁：基线 0/4，候选 4/4 通过。另一次独立复核原 4 项与新增结构测试共 5/5 通过。
- 完整 4 个 Node 文件：基线 15 通过、4 断言失败、1 环境错误；候选 20 通过、仅剩同一 Fengari MODULE_NOT_FOUND。完整命令仍 exit 1，不称全绿。
- 新结构测试和生成树测试均先红后绿。
- 原生 Lua 5.4 补充验证：battle_ui 54、looter_feedback_ui 2、looter_reward_stage 2、map_ui 27 项通过。覆盖独立/嵌入模式初始显示、战斗隐藏、真实败北文案及完整 RGBA、重开隐藏。
- 隐藏结果文字、错误败北颜色、遗漏 Lua 路由三个变异均被拒绝。
- 24 个关键基线文件逐 Git blob SHA 核对；补丁 git apply --check --whitespace=error-all 通过，仅声明的 6 个源码/测试文件改变。

## 关键证据
- evidence/head-four-gates-red.log / candidate-four-gates-green.log
- evidence/head-four-tests.log / candidate-four-tests.log
- evidence/candidate-battle-native.log
- evidence/candidate-looter_feedback_ui-native.log / candidate-looter_reward_stage-native.log / candidate-map_ui-native.log
- evidence/candidate-mutations.json / candidate-equivalence.json
- evidence/head-source-manifest.json / candidate-patch-manifest.json
- evidence/ci-40123242940-job120959147533-excerpt.log

补丁 SHA256：e39ec3e44cdf38759216b61ecf36d3907dfb2034798dad3a89aea160433fbb59

## 边界
未安装依赖、运行全量 npm、改动原作者分支或远端。原生 Lua 不替代 Fengari / Windows CI。没有官方导入、游戏实机或 verify:ui 证据；候选需集成到原 PR 后核验当前头 CI，不据此宣称可合并或 UI / M3 验收通过。
