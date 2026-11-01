# PR238：恢复 Combat.new 的可选药水目录兼容

基线 `318c9d07aab0b5580f0183c2783c54d2ff9074be`，独立树 `m3-core-optional-potions`。Root 已通过 CLI 记录计划，本片不修改 Backlog。

## 原始失败与原因

未改生产或原测试前，固定 Node24 运行原 `intent_artifact_playback.lua`，真实 status 1，2310 ms：

```text
FAIL each enemy keeps its executed face while later enemies still see new statuses: src/lua/abyss_combat.lua:2070: attempt to index a nil value (field 'potions')
LUA_INTENT_ARTIFACT_PLAYBACK 0 passed; 1 failed
```

历史合法 playbackData 只包含 rules/statuses/cards/enemies，并不使用药水；新构造表达式却无条件访问 `data.potions.potions`。不应通过给这个稀疏夹具补药水数据来掩盖生产兼容回退。

只改该一处表达式为 `index(data.potions and data.potions.potions or {})`：缺省药水 wrapper 或缺省内部目录使用空索引，完整目录继续使用原 index 路径。没有改变目录定义、药水效果、options 拷贝、RNG 或出牌/回合语义。

## 实际红绿

新增 `tests/lua/combat_optional_potions.lua`：最小稀疏真实 Combat 构造/Defend/回合、空 wrapper/空数组、完整真实药水目录逐定义保持、调用方不变和两个 Combat 查找表独立。修复前 1 通过/3 失败，360 ms；修复后 4/4，574 ms。短例使用 `runLua(path,{timeout:3000})` 并检查真实 status。

原 `tests/intent-artifact-preview.test.mjs` 六份 fixture、所有播放循环/断言和默认每脚本预算原样保留。固定 Node24 执行：

```powershell
& 'F:/New folder/build/tools/node-v24.18.0-win-x64/node.exe' --test --test-concurrency=1 tests/intent-artifact-preview.test.mjs
```

整体 1/1 JS、六份 Lua 全部通过、零 skip，总 37.833 秒；本树原始输出保存在 ignored `build/optional-potions-artifact-green.log`：

| 原 fixture | ms |
|---|---:|
| `intent_artifact_preview.lua` | 3577 |
| `intent_artifact_debuff_gates.lua` | 8105 |
| `intent_artifact_ordered_interactions.lua` | 4418 |
| `intent_artifact_playback.lua` | 12214 |
| `intent_artifact_charges.lua` | 7980 |
| `intent_artifact_cancellation.lua` | 1213 |

architecture：156 模块/899 边通过。固定 Luacheck 1.2.0 无新增诊断，105 条原历史诊断保持，battle render≤10/全部受管函数≤15原门槛通过；`git diff --check` 通过。没有修改原 Artifact 测试、runner、预算、CI 或任何诊断基线。

本片未执行全 check 或远端 CI/平台验收；Root 的独立 RNG/options 修复不属于此提交。独立集成后仍由 Root 按当前组合头完成必要验证。
