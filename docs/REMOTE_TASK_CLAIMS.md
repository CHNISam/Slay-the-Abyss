# 远端任务锁已退役

用户在 TASK-68 中批准停用额外任务锁。2026-10-26 本轮架构减负正式移除其源码入口、盘点脚本、两个 npm 命令和 29 项专属测试；不再维护或默认运行这套工具。

当前协作继续使用 Backlog、独立分支与工作树、GitHub PR，以及当前 SHA 的完整 Quality；正常代码和产品验收要求仍适用，见 [CI 说明](CI.md)。

历史实现可从固定提交 `d8a262270b959d19825932e049e76064108bd67e` 取回：[任务锁源码](https://github.com/CHNISam/Slay-the-Abyss/blob/d8a262270b959d19825932e049e76064108bd67e/scripts/remote-task-claim.mjs)、[专属测试](https://github.com/CHNISam/Slay-the-Abyss/blob/d8a262270b959d19825932e049e76064108bd67e/tests/remote-task-claim.test.mjs)、[盘点脚本](https://github.com/CHNISam/Slay-the-Abyss/blob/d8a262270b959d19825932e049e76064108bd67e/scripts/task-claim-inventory.mjs)与[旧协议](https://github.com/CHNISam/Slay-the-Abyss/blob/d8a262270b959d19825932e049e76064108bd67e/docs/REMOTE_TASK_CLAIMS.md)。

本次退役仅修改仓库文件，不操作远程 `coord/task-claims` 分支、本地 `.git` 元数据、其他会话的认领或历史工作树。已有本机 hooks 的处理仍按 AGENTS.md 的已授权任务约定执行。
