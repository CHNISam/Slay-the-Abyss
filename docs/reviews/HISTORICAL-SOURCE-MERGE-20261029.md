# 合入58f72c2c后的历史源码证明链

当前组合源码先经完整文件身份投影至 `58f72c2cc43a2833e9e1cdefe7c332ff0fd49243`，再执行原核心注册、Battle职责、Node职责、批准UI及更早入口/公告逆变换。没有将新重构直接投影成旧单体，也没有删除原中间层、放宽字段或替换原金值。

`mobile-qa-source-migration-20261028.json.gz` 保存95个完整文件的after身份与58f72原文（新增文件的before为null），SHA256为 `e70936943044626ba2a2e8c0b83b700cc5514bb64a3d0f333daa86a7e644b94e`。范围含变化的runtime、数据、脚本、Lua夹具及架构/静态配置完整源；静态配置只读取归档，未由本片改写。每个after文件都须匹配完整哈希；未知漂移不投影，继续由原层拒绝。默认从磁盘读取的Node/Battle叶同样先验证完整当前身份，再恢复58f72证据。

旧45文件归档完整保留为 `mobile-qa-source-migration-before-58f72-20261029.json.gz`，原baseline为 `1f260a71972b03dae5b63e8d6f12d055973a4c83`，原SHA256为 `be87c85b03e59705de18a6e5d4fa2691bff221ff3c0d772dfb79ee5f3eb35e5a`；其历史绑定不被重写。忽略的freeze脚本仅生成source归档，不再重映射Luacheck基线。

临时历史树先校验完整Node根、face及全部叶，再校验全部95个当前源，最后写入或删除目标树中的历史文件。旧“历史根加坏/缺叶不得触碰目标目录”负例继续通过。历史文字见证也使用精确历史树，以免将本轮中文修复伪称为旧逐字节输出；现行行为测试仍直接加载当前源码。

本轮真实验证：

- Mobile/P0/Task77及ApprovedUI/Core/Run六份源码专项13/13通过，Node职责专项6/6通过；删除、重复、移动、未知漂移及CRLF负例均保留。
- 正式入口6/6与M3原生源码守卫8/8通过，受控房间流程明确不是自然/平台通关。
- 历史responsibilities7/7通过：原361条文字、哈希1837256485，5.784秒；原81392条native写入、哈希1836812524，22.201秒（包括准备，原30秒预算）。原79543/79757及所有逐条有序比较、负例未变。
- 既有Battle原生preview职责差分通过，24.204秒；当前源与原职责逆变换比较未更换场景或金值。

初轮真实失败保留于本轮工具执行记录：直接live文字哈希变化；静态映射、controller_host未进入完整外层归档；旧Node/Core/Run测试直接拿当前源比较旧身份；临时历史写入先于Node安全预检。以上均通过增加精确历史边界及恢复预检顺序解决，不改变生产Lua或原门禁阈值。本记录不认证完整CI、官方导入、ready、平台UI或自然通关。

额外执行现行Battle七分片时，源码/seed守卫两项通过，前23个case通过后，第24个case在`tests/lua/support/battle_ui_cases.lua:648`真实断言失败：已选Defend再进入药水瞄准后，`potionAim/selected/两敌标记`组合不满足。此项已交运行时owner诊断，不能将历史proof通过替代当前交互通过；原断言和原预算保持。本归档在后续生产修复后须重新冻结after身份。

最终冻结补记：主线程修复 stationary 药水瞄准的合法敌人标记，保留moving hover行为及原case24断言，并报告原1–33与直接API副本通过。本片随后刷新95源归档；与此前暂存归档逐项比较，全部beforeSource/beforeSHA及文件集合不变，仅abyss_battle_render_actors的afterSHA变化。Mobile/P0/Task77/Node12项快速回归再次通过；原历史金值由同一完整before源恢复，未重复扩大预算或改写金值。
