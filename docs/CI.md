# 自动化检查

2026-10-26起Quality/check使用GitHub-hosted `windows-2025`，固定Node 24.18.0、Pillow 12.3.0和Luacheck 1.2.0。Ubuntu的presentation和engineering-posix保留，真实执行Windows权限环境可能无法运行的符号链接/硬链接边界。三项均是合并前必需检查。

日常官方Runner无需用户电脑保持开机或联网。沿用PR215的可信develop/master手动local-special诊断入口，只有显式选择才使用旧本机；PR和日常push不会走它。未停止、注销或改动旧机器/其他项目的服务。原self-hosted设置与掉线记录可从Git历史和[工程审计](backlog-details/task-68.md)追溯。用户已明确批准停用额外Remote Task Claim任务锁；采用Backlog、独立分支/工作树、PR审查和当前SHA完整Quality。

日常使用 `npm run test:fast -- --base origin/develop` 获取快速反馈，`npm run test:related -- --base origin/develop`验证相关集成；`--plan`只列出受影响集合。未知输入及基础设施变更回退全量。最终执行 `npm run check`，不能把快速层的成功当作完整验收。

每个Lua脚本的原有超时、失败退出、完整断言与顺序保留。Node测试文件仍隔离串行执行；进程和文件系统测试保留独立临时目录。UI保护矩阵只缩减无关fixture文件复制，每个用例仍拥有新data/out目录，不共享可变状态。

每分支原生concurrency取消过时运行；移除跨PR的self-hosted全局队列。依赖安装使用锁文件、setup-node的npm下载缓存、prefer-offline与有界重试。保留增量Git引用、按分支有界引用缓存、pack大小摘要与128MiB异常门禁；它不是网络账单。GitHub-hosted是临时机器，其缓存无需通过本机代理下载。

合并须核对PR精确head、base和当前attempt的三个必需作业，使用GitHub原生 `gh pr merge --squash --match-head-commit <SHA>`。完整源码检查、平台构建、官方导入、实机与UI体验仍分层记录。日志空白时读取对应job的原始日志，不能判为通过。

候选构建与证据合同见[ENGINEERING.md](ENGINEERING.md)。不要通过加超时、删种子、删断言或跳过有效测试处理红灯。
