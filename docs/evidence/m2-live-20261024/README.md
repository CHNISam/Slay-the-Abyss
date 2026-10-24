# M2 正常17层成功路径的原生证据

固定运行源522e547；官方测试存档1843；run bd08cab4。正常seed42从标准开局沿合法路线打败240生命Boss，在独立17层宝箱领取Sozu并进入平台官方胜利结算。未改生命、金币、牌组、敌人数值或地图进度。自动驱动使用生产控制器公开命令；不认证物理鼠标、手机触摸或整体UI品质。

本轮新25号日志完整解出4032条打印，ready和driver ready各1次，266动作全部成功，286组主账本/资源分片连续。1–17层各一次，客户端胜利请求及服务端胜利打印各1次。最终34/80生命、131金币、17牌、3遗物、8胜；金币、永久UID和药水库存变化闭合。

- [manifest.json](manifest.json)：所有原始/压缩文件的字节数与SHA256、版本与边界。
- [native-log-review.json](native-log-review.json)：本轮ready、17层、胜利和结算记录；完整解码在decoded-log.json.gz，原始GIA在session-log.gia.gz。
- [independent-native-review.json](independent-native-review.json)：另一代理的独立解码、逐层合法边与资源闭合、截图时间对应和缺失证据。
- [official-readback.json](official-readback.json)：官方副本45模块与显式测试候选一致；普通43模块的核对见normal-candidate-audit.json。
- [screens/24-t250.jpg](screens/24-t250.jpg)：游戏17/17胜利结果；[screens/27-level-ended.jpg](screens/27-level-ended.jpg)：平台官方胜利结算。
- fixture/保存测试驱动、只读策略及修改入口的精确原文压缩包；普通生产manifest不含这些测试模块。

原runner-status-original.json.gz中的logFile:null保持不变；原始Windows换行也由压缩包逐byte保留，request.json.gz同理。自动工具发送离开后实际仍停在官方结算；后续按新截图真正点击“离开”后，16:29:59生成本轮2026-10-24_16-17-23_25日志。副本与官方原件的SHA256相同；这是同一会话的延迟落盘，未使用14点的旧日志。

本包不证明正常失败、游戏内重开、平台重新挑战、药水使用或商店买药。间隔截图未逐个拍到所有节点事务，相关事务由本轮完整日志与已核对生产模块共同证明。PR169的新选牌容器在这份候选冻结后组合，单独做本地验证，不把本包当作该新布局实测。M2整体仍保持进行中。
