# 蜥蜴尾巴数据小片

基线为 `19594833bf951e6bb11c1c16e9ff778ecf497f25`，已含独立Tail callback。本片仅在 `data/relics.json` 追加一项 `lizard_tail / Lizard Tail / rare / hooks / effects=[]`，并在实际分类入口 `config/architecture.json.layers` 将 `abyss_lizard_tail` 登记为core。仓库没有 `config/module-layers.json`，已由主集成人确认采用实际入口；不新造无效配置文件。

固定来源 `sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`：`relics/LizardTail.java:15` 明确RARE，24–40明确一次性counter与onTrigger；成员SHA-256为 `9ee5bd6aad4aa34a4d79cdd69f97160913b71d0f9e727f9ae8d7b26e2f281b90`。完整成员/归档与pure边界继续由 `tests/fixtures/lizard-tail-source.json` 保存，不改变其事实或声称已接通。

三项纯JS合同先真实RED：缺定义、缺core分类；四职业原池中的Rare Tail身份原本已存在。最小修改后3/3 GREEN（76ms），核定具体sourceId、rare、既有hooks与空effects、中文说明、core分类及四份未过滤源池中Tail只出现一次且仅属rare。没有修改队列、概率、重抽、其它定义、共享脚本或launch-content验收profile。

**当前完整数据校验仍RED**：`node scripts/validate-data.mjs` exit1，仅报 `relics[53].id: unsupported relic hook`。这是主集成人负责的既有hooks白名单尚未包含Tail；没有放宽其它ID或新增trigger，也没有把该失败当作通过。首次架构检查因新树尚未安装luaparse而失败，离线npm ci后实际架构检查通过：208模块、1209条边。

父需在统一叶接真实onObtain/init、fatal Mark→Fairy→Tail顺序、Run/事件/存续/可用状态UI及精确白名单，并在同一最终SHA做完整验收。只有这个定义不代表合法获取后效果可用或已进入当前冻结测试包；本片没有运行任何Lua、游戏、GUI或平台操作。
