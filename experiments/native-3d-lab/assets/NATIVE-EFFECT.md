# 一条官方限时命中特效

复用 `effect_catalog` 的 `黄色闪光`：ID **7**，`kind: timed`，时长 **1.17秒**。已核对本机D版官方编辑器目录读数及 `fx-thumbs.bin` 第5472字节开始的1025字节缩略图；缩略图已查看并保存在 [native-hit-thumb.jpg](native-hit-thumb.jpg)。这是目录缩略图，不是本轮实机截图。`nativeHitEffect()` 返回来源文件与缩略图SHA256，目录身份变化会拒绝构建。

父构建调用 `installNativeEffect({call,nativeScene})`。`call` 必须跟随当前存档副本；函数不传旧mapPath，不回滚其他实验。只改已有服务器图内通过busy/动作能力检查后的hit分支：`playTimedEffects(7, unit, 'GI_RootNode', true, false, [0,1.4,0], [0,0,0], 1, true)`。攻击、伤害、仇恨、结算和旧8秒超时均保留，未新建桥、图或UI。

新增维护只有1个官方资产引用、每次有效hit的一条限时特效调用；自动结束，无循环清理。保留原2D反馈，因此本样例是替代潜力演示，**没有证明已减少控件、Lua桥调用、GPU或内存消耗**。玩家模型位置/音量、可见性、手机表现仍待当前候选实机。无受击clip的模型原分支仍返回unsupported，不绕过已有失败边界。

`addNativeHitEffect` 精确检查原生服务器源的分支锚点及数量，重复安装或源变化会拒绝；成功编译读回后才更新 `nativeScene.sources`，供父构建继续审计同一真实源码。
