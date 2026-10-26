# 转化神龛生产切片（2026-10-26）

固定事实来源仍为 aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0；本地只读 ZIP SHA256 `3f42bd7dde08126a9a8a02fc8eed8856c7b8b0dda551f50c62ced838e41ed458`。`events/shrines/Transmogrifier.java` SHA256 `decf6448c7b6c7dae59aa622be79efc38b9ec38d6b2e852df4d4e6f28b2a9951`。该镜像不是正版 PC 二进制认证；不提交其实现代码或表现资产。

源事实：源 ID 拼写为 `Transmorgrifier`，初始变换/忽略二选一；变换仅从非瓶装可清除牌选择，选定后先永久移除，再使用当前房间 misc 转化，获得未升级新卡；两条路线均保留完成说明及离开。空合法列表按现有平台空选牌降级直接显示完成说明，不挂死界面，不抽样。

生产通过 EventPool.contentId → Nodes.enter → Act1Events → NodeUI 原生选牌器 → Nodes.chooseAct1EventCard → Run 永久事务。给 Living Wall 与转化神龛共用的默认上下文补齐当前普通池、源罕见/稀有池与完整35无色/10诅咒槽；仅将完整源池映射到已定义本地卡牌，选中未实现结果仍整体拒绝，不过滤、不重抽。显式传入的测试上下文继续支持。当前默认旅行者红牌上下文与独立固定来源夹具逐槽一致；其他职业若缺其对应源池会明确拒绝，不变成红牌池。

本轮红绿：新核心首次失败于缺失 contentId；原生 UI 首次失败于无神龛展示，补生产路由后核心4组、原生 UI 1组通过。重复输入、非法按钮、瓶装 UID、空牌组、失败引用与所有 RNG 回滚均覆盖。旧 Living Wall 缺失上下文拒绝用例更新为“上下文及其生产 sourcePools 同时缺失”，保留原全部拒绝断言。

本地相关验证：transmogrifier、transmogrifier_ui、living_wall 三分片（72源槽）、living_wall_ui、act1_event_content；架构和语法检查。固定 Lua 静态检查结果由实际执行记录补充。默认 restricted-seven 没有扩池；新增源映射不是完整25事件自然获取/概率验收。配对事件、其他缺失事件、统一全池开关、候选构建/官方导入/同候选实机与总 UI 门禁仍未完成。本轮未操作游戏、鼠标或键盘。
