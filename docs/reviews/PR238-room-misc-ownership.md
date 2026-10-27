# PR238 房间随机流修复

冻结 `d8f33a7c` 完整本地JS为1612项：1489通过、4失败、119个既有Windows权限跳过；其后Lua及后置门禁未进入。原日志保留在集成树 `build/frozen-complete-check.log`，不是完整check通过。

原Gold七种子42步向量先失败于seed0第二房间：构造回调消费了真实room.misc，但完整目录分支深复制options后，battle读取另一份roomStreams，奖励时将游标倒退。只复制两个默认标量所在的options外层容器，保持回调与来源owner一致；不改调用方默认字段。

该修复后原向量继续真实失败于Boss：Gold.prepare已消费misc，随后applyPermanentChanges又从战斗游标覆盖它。现在在奖励准备之前校验并同步战斗misc，奖励之后不覆盖该游标；无效永久owner依旧拒绝。

原42向量、原13组边界和原3项JS完整通过，总29.115秒，向量与预算零改动。另两组回归1.050秒核真实Small Slimes回调/来源owner、调用方默认项及私有battle游标，以及独立原Boss向量、冻结金币、重复领取。后者为终局奖励边界，不是自然打败Guardian。

架构156模块/899边通过。固定Luacheck105条历史诊断按同file/源行/column/code/message及引用源行一对一迁移位置，无新增豁免或阈值变化。其余CI失败另独立处理；当前组合SHA完整CI仍待验证，没有平台或实机结论。
