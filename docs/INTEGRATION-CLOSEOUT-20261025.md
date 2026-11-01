# 2026-10-25统一集成与清理

用户要求把交接PR、独立分支和在途内容统一集成，并清理多余分支与工作树。复用[PR206](https://github.com/CHNISam/Slay-the-Abyss/pull/206)交付最终组合；完整CI、最终HEAD及实际合并状态以该PR为准，不把下列定向结果当成完整CI或实机通过。

| 来源 | 固定头 | 处理 |
| --- | --- | --- |
| develop交接基线 | c1cb78e8fcbeead0c8439477c39b75f9f4429e8f | 保留正式source formation、完整75战士卡及已批准移动布局 |
| PR206事件/库存 | 162dcfb1884a8e206643b740670f474f3182f2b6 | 保留全部生产接线；仅拆分已证实超时的两份夹具 |
| PR208美术压力样板 | f14feb486a4ed02f3b481991320fa53a3df8582f | 41档2D/2.5D/3D独立工具与源资产一并集成，不替换正式游戏美术 |
| PR202玩家评论研究 | 0433636b89d3c1841f905e8875b7bb3bd52fc9bb | 研究文档集成，不把反馈建议当成新增玩法授权 |
| 工程检查 | 417f5f914db6a04ad16fc957752450920f234426 | 构建/证据/架构/静态/变异门禁迁到当前源；历史33/34/35任务不覆盖当前同号产品任务 |
| 药水独立候选与评审 | 5532db9480c3c604b0f6a0f327a0df3bfcbb02f5 | 保留候选与审查历史，对接39项回归；生产沿用较完整的potionAim |
| 红绿虫候选 | 862b0a64d88a47b3b91a35154fbd5c8133f55e53 | 补显式legacy入口的逐槽颜色；正式地图已有formation，禁止重复消费随机数 |
| 客户端源码保护 | 1d804c36452c0e208a7f60010af5249180d8ca14 | 三份实现/证据文件已与develop逐blob核对相同，保留较新的操作指南 |

表中固定提交均为原始交接/来源，不冒充最终组合HEAD。PR202/208的内容通过同一组合验证后，由PR206统一收口，原PR可标注为由整合取代。

## 已取得的定向证据

- 原53个战斗UI用例分为26/27两份，全部正文与中间helper的冻结SHA256为`d97b7f1b44cb4c4655f9ae06ec429f88f40bfd322ddb1aa8ab30e4c2d08b9678`，新守卫核对全53序号无漏无重；每份仍60秒，实际生成布局同时注入。
- Living Wall的10个非矩阵用例正文与helper保留，SHA256为`33a25b6b5f0e79f9e771fd9ad085dc07eab4815fdfd15162c1a2886a4f34b788`；72个源转换槽分24/24/24，由固定来源`pools.json`独立核对序号、来源ID和全覆盖，每份仍30秒。分片与运行器9项回归通过。
- 药水39项确认/取消/旧触摸/同ID补瓶/失败原子性回归通过；节点名单变化或EndDrag仍取消瞄准。红绿虫273项通过，保留12种有序颜色、24组事务失败/重试及其他16遭遇完整状态比较；夹具是显式队列/事件流检查点，不是自然通关。
- 工程契约20项通过；66模块/198依赖边通过分层。四条已审查回调依赖只有在函数体内才允许延迟；未知循环、顶层循环、跨层及动态加载仍失败。114条既有非硬错误告警逐条留准确位置与源hash，0未定义全局/语法错误；固定Luacheck与四项指定语义变异通过，M2锚点限定到真实抽牌循环。
- 新会话交接使用原生`migration-transfer`保留旧claim、阶段、来源指纹和审计，重新adopt取得新generation。原26组真实Git回归通过；归档评审的两处到期问题先红后绿：过期续租不启动子进程，本地到期不被远端同步Git阻塞；另有真实bare remote/真实子进程超过初始租约仍可正常续租完成的正例。

原始本机日志在根`build/`：`claim-transfer-full.log`、`pr206-timeout-slices.log`、`potion-candidate-combination-green.log`、`louse-combination-calibrated.log`、`engineering-combination-green.log`、`engineering-gates-green.log`、`lease-boundary-red.log`、`lease-boundary-green.log`、`lease-helper-real-green.log`。早先断言、网络中断和权限审查超时保留原记录，不能记作通过。

## 保全与清理

开始时16个工作树（根加15个额外树）、7份脏状态和6条stash已盘点。全部分支先保存并验证`all-refs-before.bundle`；7份脏状态有ZIP、暂存索引、binary patch和逐文件SHA256。归档根为`.artifacts/integration-cleanup-20261025/`。

最终清理前须给每条stash建立可追溯archive ref，重新创建并核对最终bundle；仅有`--all`的最初bundle不能证明保存了stash reflog的所有旧条目。原工作树（包括ignored构建/取证文件）整体移入归档并登记，核对PR原头无新增成果后才删除活跃分支和prune注册。根在途备注通过Backlog CLI迁移，误写为`--append-plan`的两条负责人改为Furinya；CLAUDE美术分工和新版桌面操作守卫保留。

本轮不重写master，不改0.1.0版本，不发布。协调分支是执行权元数据，外部未知与保守迁移状态不伪称已核验；释放本轮执行权并保留历史。最终干净状态、实际合并SHA、远端分支与工作树列表写入同归档的收口记录。

## 游戏验收边界

本轮没有操作鼠标键盘、官方导入或真实试玩。旧`8c8f0461…`候选仍属于原固定源；源码组合改变后不能作为当前RC。M3自然获取/完整事件池、同候选UI门禁、手机与最终RC验收保持原任务要求；Git集成完成不提升这些状态。
