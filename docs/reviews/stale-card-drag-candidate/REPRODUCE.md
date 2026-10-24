# 执行清单

目录：`<candidate-directory>`。

1. 在干净目标工作树核对当前head，保留已有在途修改；不要整文件覆盖 battle UI。
2. 执行 `git apply --check <candidate-directory>/candidate.patch`。本地核验对 develop 9ae1aec 和当前 PR196 df64701 的等同源码均通过。
3. 经原集成者决定接入后，执行 `git apply` 同一补丁。
4. 按项目正常流程重建数据和UI，执行新增 `tests/lua/battle_ui_drag_source.lua` 及相关输入/卡面/药水套件，再按当前SHA执行正式门禁；不以本轮Native结果替代Fengari/完整检查/实机。

本地候选可重现命令：

```sh
cd <candidate-directory>/candidate
python $LUA54_RUNNER tests/lua/battle_ui_drag_source.lua
```

精确基线负控（测试相同，生产源不同）：

```sh
cd <candidate-directory>/base
python $LUA54_RUNNER ../candidate/tests/lua/battle_ui_drag_source.lua
```

证据入口：`evidence/red-final.log`、`green-final.log`、`final-suite-results.json`、`mutation-results.json`、`pr196-red.log`、`pr196-green.log`、`candidate-sha256.json`。原始所有失败及runner适配错误均保留。`evidence/battle-ui-wrapper.lua` 只注入官方测试要求的真实battleLayout，不修改测试断言。
