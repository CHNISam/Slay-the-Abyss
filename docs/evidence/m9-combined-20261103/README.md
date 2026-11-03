# M9 当前组合测量

`quality.json.gz` 保存本轮完整成功工程采集，原始采集HEAD为 `3527ef76ed290267acd2e48673a9b7d078507532`；后续只补政策、测试、任务与文档。`summary.json` 记录原采集身份、Node版本、gzip SHA256、全322份Lua规范换行SHA256及冻结基线的同口径比较。生成时独立发现全量Lua并逐文件匹配原报告，不把后续文档提交冒称为已采集HEAD。

在目标组合树执行 `node scripts/check-engineering.mjs` 可重新完整采集，再将 `build/engineering-quality.json` 的全部 `snapshot.modules[].file/sha256` 与 `summary.json.sourceHashes` 比较。摘要可由全部modules/functions、dependencies及完整cycles重算，不只报告选中热点。gzip按二进制核对SHA256；文本按Git记录的LF字节读取。

38项Actor/Runtime/CI/原Task77与deck/delivery组合回归、30项消耗动作/compendium/架构/静态政策合同通过，均0跳过；四项关键变异及六项原生合同通过。门禁RED/GREEN和原compendium三项失败均保留本树build日志。最终组合独立复审、托管CI与合后复核单独记录，不能由这份本地采集替代。

完整Git Blob/LFS盘点继续使用[冻结基线](../m9-baseline-20261103/README.md)，没有迁移资产、移动Lua目录或删除历史证据。全局仍282个函数CC>15、78个CC>30，最大SCC105模块/809调用点；报告不自证所有热点治理完成。官方候选、导入、ready及设备性能均未执行。
