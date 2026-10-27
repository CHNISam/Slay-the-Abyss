# PR257 原生字段修正后的轨迹回归

失败源为 PR257 `9ba8e7e487bfd7c69cbd3363785eb1a052d339fc`，Quality运行 `40540556781`。三个真实失败全部是相同的测试记录器适配遗漏；不是超时、随机玩法失败或需要放宽的冻结合同。

| 作业 | 失败入口 | 实际错误 |
|---|---|---|
| engineering-posix (1/4)，122317468761 | presentation-responsibilities.test.mjs 的trace合同，5.167秒 | presentation_trace.lua:33 把function类型的原始__index当table索引。 |
| rules (1/8)，122317469301 | 同一JS包装，5.528秒 | 同上。 |
| rules (6/8)，122317469066 | 原始presentation_responsibilities_trace.lua，7.521秒 | 同上。 |

engineering-posix与check聚合失败是上述结果的正常传播，不另造基础设施问题。下载客户端曾遇到无效ZIP缓存和一次重定向EOF；最终三份真实作业日志均已读到并保存，不能把客户端取日志问题当作CI失败原因。原始日志位于本树忽略目录 `build/pr257-ci-40540556781/`；摘要和hash见 `docs/evidence/pr257-native-trace-ci-40540556781.json`。

P0严格原生mock把__index改为函数，以拒绝CursorArea.interactable及activeInHierarchy。旧trace记录器只支持table，而且把kind移走会失去严格校验的raw类型标记。此次仅改测试侧：支持原函数/table索引委派，保留raw kind，写入委派原setter校验后继续记录，避免后续原生字段被raw写穿透。没有产品Lua或公共Run/Nodes变动。

原轨迹恢复仅逆转换P0已批准的字段差分：PresetButton新增raycastTarget镜像不重复计旧interactable语义；三个明确pile路径的CursorArea.raycastTarget按旧轨迹键记录。实际控件没有interactable别名，严格读写仍报错。新增同步检查要求所有被记录PresetButton两字段一致；不同步会失败。非pile的CursorArea字段和其他写入保持原始次序及hash保护。

新增最小mock先真实RED（1.434秒，重现同一__index错误），修后GREEN（0.906秒）。最终三项完整定向回归全通过：原文字1.693秒、原有序原生轨迹24.258秒、严格mock0.730秒。原轨迹仍为 **72915 / 148113441**，原文字仍为 **361 / 1837256485**，原单Lua30秒预算、场景与断言不变。没有删测试、重写预期hash或扩大预算。

修复基于独立native-cursor-interaction树 `7f6ded37`；相关fixture/轨迹源与失败PR头一致，未混入主线程事件桥。下一步由主线程挑取到PR257并验证精确新HEAD的完整Quality；当前只证明本地定向修复，不宣称远端绿灯或M3完成。没有GUI或桌面输入。
