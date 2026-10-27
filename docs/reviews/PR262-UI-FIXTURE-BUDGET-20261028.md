# 保留完整界面回归并缩小测试进程

develop的真实push Quality `40567299031`、attempt1、head `e0fad45c74ed574bc4cfb8a4c9ad71424a13c386` 最终15作业中13成功；rules(8/8) job `122411878339`及随后的check聚合失败。作业17分32秒，Lua步骤13分21秒；两份fixture各触及原30000ms进程上限，没有业务断言FAIL。PR曾通过不替代这次合并提交的实际结果。

原日志完整保留在执行树 `build/push-e0-40567299031/job8-raw.log`，1019072字节，SHA256 `4b4985b860aa41435ea6326c24b6e01ba1935f925da5710bee114219276f8444`。873行card_help_release超时，已输出8个PASS；2936行looter_potion_ui超时，已输出前三个顶层组PASS，第四组尚未完成。整体run尚在运行时，使用completed job的直接只读logs API取得日志；未盲目重跑。

修复基于冻结 `c5e768807081d1c62750174998367f1565274ee5`，两份原测试与e0字节相同。card-help原31个注册case按原顺序划为8片：每片4例，最后3例。Looter原8个顶层test组各一片，组内全部控件、held/released、重绘、外部领奖与生命周期循环保持。原入口负责第一片，新增wrapper负责其余范围。

两份原文件通过移除仅有的选择/计数代码可精确恢复原全文SHA；两个原共享fixture输入的SHA同样锁定。改断言或真实牌输入的负例会破坏原hash。raw自动发现、各wrapper范围及JS包装共同覆盖全部16片且不重复。原setup、seed、真实Run/Combat/controller命令、触摸ID、计时、重试与全部断言未改；默认及专项包装仍为30000ms。生产源码、数据、配置、art、mock和workflow均无差异，GIL的c5生产输入不变。

机械守卫先真实RED（缺少显式分片），再GREEN。16份新raw片全部真实GREEN：card31例8/8合计27.204秒，looter8整组8/8合计25.722秒，最大单片7.947秒；两份静态守卫通过。记录见 `docs/evidence/pr262-ui-fixture-budget-40567299031.json`。这些是两次串行有界专项，不是一次完整Quality通过；修复提交仍须父线程独立审查并由同一PR262的新SHA完整CI验收。没有操作GUI、远端或Backlog。
