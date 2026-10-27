# 终幕资格与真实胜利历史

本切片把初代三职业胜利历史与Neow上局进度分开。来源为固定社区反编译镜像`aeubanks/sts@319009d5df0a82d9fb0f23cc22322286c6a87ec0`；精确文件摘要见[来源锁](../../tests/fixtures/ending-history-source-lock.json)。它不是官方开放源码或正版PC二进制执行证据，产品不包含Java正文或原作素材。

## 原版边界

`Settings.setFinalActAvailability`要求战士、猎人、机器人三个`_WIN`标记，并排除daily和trial。观者不参与这三个标记的解锁条件。`CardCrawlGame`只在标准胜利时首次写入当前职业`_WIN`；`Settings.isStandardRun`还排除手动固定种子。已具备历史资格的固定种子局仍可使用资格，但其胜利不能新增标记。

Neow使用的`_SPIRITS`/`bossCount`表示上一局走到的边界，失败或弃局到16层也可能为1。它不证明三幕通关，本模块不导入、不读取或改写`abyss_neow_history`。

## 独立接口

`EndingHistory.new({read=...,write=...})`创建一个Host私有的历史owner。Host可通过`platform.readEndingHistory`和`platform.writeEndingHistory`提供适配器；没有适配器不影响正常开局，也不伪造历史。

- reader无参数，返回严格普通表`{version=1,wins={ironclad=boolean,silent=boolean,defect=boolean}}`。缺字段、额外职业、错误类型、元表或异常都按未知处理，不采用部分返回值。读取结果复制后缓存于本Host。
- writer收到一个独立的单职业真值增量，例如`{version=1,wins={silent=true}}`，必须合并这个标记，不能覆盖其他职业。只有明确返回`true`才记为适配器已确认；这不是本切片认证了真实平台落盘。
- `begin(owner,run,context)`在Start时捕获原职业、是否原创V4、原始种子及`seedSet/isDailyRun/isTrial`三个布尔事实，返回独立资格状态。Host在`Map.generate`之前读取并设置本局`endingUnlocked`。后续修改规则状态不能把固定种子局改成标准局。
- `read(owner)`返回独立的已知胜利、`known/unlocked`及来源/存储状态。未知职业不写成false；三个真实会话胜利可以逐项补齐未知状态。
- `finish(owner,run,map)`只接受同一owner登记的Run。当前必须是标准campaign第三幕51层普通胜利，且Run、来源地图、路径末端、结局节点及上一场Boss胜利身份一致。默认旅者的规则包记为ironclad；观者、未知职业及原创V4角色不能贡献三原职业标记。失败、弃局、第一幕旧胜利和重复结算都不贡献。

本局资格在Start时冻结，之后取得的历史胜利只作用于下一局。writer缺失或失败不会抹掉真实会话胜利，但状态明确为未持久化/写入失败；新Host不能把旧Host内存当成已保存历史。未知读取且会话三胜未齐时始终未解锁。daily/trial即使已有三个历史胜利也不开放本局终幕资格。

## 当前交付与验证边界

这里只承诺会话内真实胜利记录、Host必要接线和可注入的持久适配接口。仓库尚未提供经过原生平台验证的历史存储适配器，不自动升级账号，不伪造已经持久化。燃烧精英/绿钥匙、第四幕战斗和心脏真结局不在此切片中。

纯owner回归验证未知/损坏提供方、严格模式、三职业独立记录、默认旅者映射、原创角色排除、重复拒绝及存储失败。Host回归使用真实Start/Nodes普通终点命令和受控章节边界，核对先读历史后生成地图、下一局生效及固定种子锁定；其中的受控终点不是自然通关证明，也没有注入三钥匙。最终同候选自然流程和平台记录仍需另行验收。

本轮已实际执行：纯owner缺模块断言先RED后8组GREEN；Host历史读取顺序先RED后3组GREEN；复审又以无profile但带`originalV4Role/originalV4Rules`的历史预装数据复现误记胜利，先RED后GREEN，并保留普通ironclad历史组件可记录的反例。最终专属Node包装3/3通过（owner约0.191秒、Host约5.636秒）；此前与Neow入口及章节Host一起串行8/8通过。全部Lua维持原30秒单夹具预算，没有跳过、降断言或延长超时。

固定ZIP归档hash及四个来源成员的大小、SHA256和Git blob hash均独立读回一致。架构194模块/1120边通过；固定Luacheck 1.2.0零新增、84条既有诊断，358条职责测量通过，未改静态基线。`git diff --check`通过。上述结果只认证本地切片，不认证最终组合SHA的完整Quality、平台历史存储、自然三幕或隐藏第四幕实玩。
