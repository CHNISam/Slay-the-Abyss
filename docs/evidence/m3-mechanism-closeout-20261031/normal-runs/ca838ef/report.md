# Living Wall 离线driver阶段协议续办

提交 `ca838ef6f36fedc1ed55a8eeeaafe9370149cb0d`，基线 `c3d2654`。仅修改离线m3-event-card-policy与新增两个测试文件；玩家生产Lua、完整池、策略评分、随机消费与预算不变。

原C3自然seed17第38步在Living Wall初始阶段发送forget+UID1，被生产正确拒绝。helper现依据公开picker descriptor及choose_card阶段，初次仅发送操作，进入选牌阶段后才发送候选UID；grow使用公开upgradeCards。没有按事件ID猜测过滤。

标准新测试先真实RED，再与原Bonfire/Blacksmith/Transmogrifier一起GREEN：2/2 JS测试、7新分支边界及3旧分支通过。新边界包括实际忘却/变换/升级结果、空候选、真实瓶装牌排除、全不可升级、初始UID/错操作/迟到命令拒绝及完整资源/RNG原子性；每Lua仍默认30秒。

在干净fix提交上只重跑自然seed17（300秒原预算）：第38步forget不带UID成功返回choose_card；第39步forget+UID1成功，永久牌组12→11，phase node→map。同一真实流程继续至第一幕16层后战败，HP0、184动作，无失败公开命令。它证明原阻塞已解除，不是自然双幕胜利。

本目录保存原summary/gz/coverage、源码与四策略hash和产物字节清单。旧C3五seed批次保持在兄弟目录m3-natural-c3d2654，身份不混合。没有推送/改PR/动主树；新Run构造隔离仍不是Host重开或官方设备证明。
