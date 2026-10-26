# 云端真实 Fengari 定向验证

环境：dot云Linux、Node24.22.1、仓库锁定fengari-node-cli0.1.0 / Fengari0.1.5。每个fixture保持30秒上限，顺序执行；不是Windows CI、完整项目check、平台编译/导入或实机验收。

- 奖励测试：固定088原文件真实红，候选真实绿。按仓库scripts/test-lua.mjs的 -e dofile 调用方式，基线0.652秒exit1、候选13.765秒exit0/完整通过marker/空stderr。初次positional调用会错误返回exit0但打印Lua错误，results.json保留该记录；它不算PASS，最终以project-mode-results.json为准。
- 纯seed候选：088增量快照上新增7组全部通过，0.392秒。
- 死亡反伤v2：固定9a4候选原反例与7组反应、6组边界、缺HP兼容共15场景通过。只确认本次命令的有限执行；探针保留旧的“native Lua only”字面footer，实际引擎以日志命令/本页版本为准，未篡改测试来改标签。
- card_help_release：固定main c053，基线12.305秒、候选7.216秒，均31/31且stdout逐byte相同、stderr空。基线也过，不能据此认定Windows超时根因或已修其CI；只是本云对照成本下降。

相关候选分别位于pr196-reward-pool-regression、pr196-seed-validation-performance和pr196-death-guard-candidate归档。没有把候选推入原PR生产分支，没有借旧CI替代新候选门禁。
