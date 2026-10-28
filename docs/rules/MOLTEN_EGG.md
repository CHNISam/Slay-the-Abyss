# Molten Egg 本地单件

基线 `4a316780`（远端 develop，含 PR282）。本件只新增 `Molten Egg 2` → `molten_egg`（熔火胎石）；Frozen Egg、Question Card、Busted Crown、Singing Bowl 仍未实现，不宣称遗物全池完成。

固定社区反编译镜像 `aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`，本地原ZIP SHA256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。`relics/MoltenEgg2.java` SHA256 `415e68f17fd5fa4fb123344341c12adfa8318bc6a942c9c283f38341b035183f` 已实际核验；26–44行只对可升级且未升级的 ATTACK 升一次，装备仅访问 CombatRewardScreen.rewards，预览调用本遗物获得逻辑；48–49行为非 Endless floor<=48。它不是认证正版PC二进制。

七成员精确源锁见 `tests/fixtures/molten-egg-source.json`；只读复核命令为 `python tools/oracles/sts1_molten_egg.py --source-zip <本地ZIP> --check`，不下载或执行原作。

## 所有权

复用现有 Toxic Egg 的 staged permanent transaction 与奖励预览入口，以实际卡类型分派。保持获得前预览、普通奖励先消费随机升级、成功随机升级跳过预览、获得前回调和持有顺序。预览不消费RNG、不创建UID、不加金币；真正获得只升级一次，陶瓷鱼仍只真正获得时加9金币。双Egg按各自类型组合，技能/攻击不会互相错升。

装备只更新未解决战斗奖励和Sensory Stone未领取组（包括已打开组），不追改旧牌组、旧货架、Dream Catcher已展示的直接列表或临时生成牌。商店购买遗物后的 StoreRelic 预览刷新与初始商品、Courier补货仍走原owner；购买前已有货架不由单独onEquip修改。Library的20张完整职业来源和Sensory的完整35无色池只解除Molten门禁，不缩池或改身份、价格及随机流。

完整来源队列、原始注册顺序和概率不改。正式shop/treasure通过受控队列首尾checkpoint核验floor48可出、49消耗拒绝候选继续原池；这不是自然获取或通关证据。既有普通受限来源的fallback资格同步保留floor48上限。原有Toxic行为与其来源锁不变。

## 验证及剩余边界

新增真实公共获得四组在实现前全RED `relic_content_unavailable`，实现后4/4 GREEN。新增短Lua组覆盖获得/已升级与不可升级负例、装备追溯、循环引用和奖励owner回滚、商店同源价格/RNG/补货/晚失败、休息奖励、Sensory三组与Library四职业完整20张、四职业及原创V4下一战同UID、48/49资格、StoreRelic预览。临时生成攻击牌使用真实Blade Dance→3张可升级Shiv作为不升级对照。

主题只加显式占位图标；历史严格主题门禁以精确新增块逆投影恢复原hash，拒绝新增块改名/改值/缺失或任意旧主题变更，未更新历史截图/trace或放宽预算。完整自然获取、当前候选构建、官方导入、实机和专用美术均未验收，TASK14.1及M3不能据此Done。最新实际测试结果与PR SHA见PR验证记录。


## 与在途事件集成

PR267 的 Nest 若仍显式拒绝 `molten_egg` / `Molten Egg 2`，应在本件合入后仅解除Molten拒绝并用其真实获得牌入口补邻接回归；Frozen和其它缺失owner继续原子拒绝。本分支基于远端已合develop，不预先修改尚未合入的Nest文件。

本地实际检查：19项来源/历史主题契约通过；架构213模块/1235边；Luacheck1.2.0保留84条显式历史诊断、零新增；4个原工程语义变异均被原断言杀死，2项原生UI契约通过。完整npm test已启动，曾见 `act2-intent-ui.test.mjs` 的原30秒Lua超时，尚未宣称完整通过；最终当前SHA的远端Quality需独立确认，不能用专项结果代替。
