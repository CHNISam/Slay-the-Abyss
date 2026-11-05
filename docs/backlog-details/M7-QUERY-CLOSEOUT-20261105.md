# PR514 实际合后收口

最终来源头 `a2457383a7813b29fca49509f7b6626419f2da79`，基线 `a308edbfde7792485cbe79b5650c17e1c7de98cc`。实际squash `78e4e746a7f05754f0d838999c466cd88630368c` 的唯一父为该基线、源码树为 `1e7781287c628ae94b5ad8c5be809941de4be3ba`，与已审候选一致。

来源Full [41914042810](https://github.com/FurinyaWorks/Slay-the-Abyss/actions/runs/41914042810) 29:06、原生队列Full [41918738466](https://github.com/FurinyaWorks/Slay-the-Abyss/actions/runs/41918738466) 33:05、实际develop推送Full [41923895912](https://github.com/FurinyaWorks/Slay-the-Abyss/actions/runs/41923895912) 30:03，均成功。每次27作业、26成功及按Full合同跳过的Fast；每平台710 JS文件、1355份raw Lua完整且无文件重漏。既有条件用例skip保留，不声称所有用例零skip。API原始时间戳时长之和分别374.900、387.967、361.500分钟；push的跳过Fast结束时间早于开始1秒，逐作业取非负时长之和为361.517分钟。两种口径均不是CPU或计费读数。

原验证器最终证据 `build/delivery/f818a966-1e43-467c-b371-2cc6acc621eb/evidence.json` 为 `merged_passed`、errors为空，来源预审为 `1e1dff4b-31d1-4b96-a824-627222a4bb64`。两组真实独审最终记录分别位于 `build/query-output-review/final-review-a2457383.json` 和 `build/status-runner-review/final-review-a2457383.json`，绑定同一head/base/tree。完整原始产物归档位置见文末，不能用附件文字替代验证器。

PR515已通过CLI收口TASK-74.14、74.15、74.16及75.2。本页补充找回的原schema3合后回执及本机补验；PR515当轮“未取回”的历史陈述、原失败与原证据均保留，不伪造schema5。后续74.17/74.18使父74重新进入工作中，不重开这四个已交付子任务。

同环境完整Silent原夹具按严格BAAB四次补测，before均值20.3061522秒，after19.5719249秒，减少3.6158%。三模块完整旧新源身份已核验，全部stdout及8份完整canonical逐字一致，四次均在原30秒内。仅为本机Fengari小样本，含未校准观察器开销；不作单helper归因，不与前批百分比相乘，也不作原生Lua、设备或托管流水线提速结论。原记录为 `build/query-runtime-perf/REPORT.md`。

自然Fast审计未获得20个正式成功样本：最近100条Quality中98份jobs可读、2份未知，实际Fast成功0。Quick的47个独立最终头PR中46成功、1取消，成功wall描述P50为4:27、P90为14:16；Quick不能替代正式Fast验收。原记录为 `build/fast-natural-audit-78e4/REPORT.md`。父TASK-74、75及M7继续开放。

本批工作树清理前，全部非生成/工具build证据已归档到仓库本地 `.artifacts/m7-query-20261105/source-build/`，以上build相对路径在该目录下保持。独审逐一核验2107份文件、144090941字节及清单SHA b75a55c66b56ce39326587f984ce8af061a0912903ad168f37b694c915789104；完整Git bundle另保存四个来源分支和全部历史，SHA256为e18f85367da53532bdd97f58884f75a7cc22ef0b7d07d5d2236df7907605e0c5，`git bundle verify`通过。再次确认旧头未移动、树与实际合入一致且无新工作后，仅清理m7-closeout工作树和feat/query-hotspots分支；共享依赖及其他工作树保留。
