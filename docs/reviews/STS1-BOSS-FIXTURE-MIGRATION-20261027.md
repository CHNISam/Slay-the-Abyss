# Boss/章节回归迁移

复核基线为 `2425ad622eed31ad6a965b90086a6838a1db96f4`。本提交只修改测试和证据，不修改生产数值、池、随机流、超时或CI作业。

原 Boss 宝箱 fixture 固定要求 Black Blood/SlaversCollar/Sozu 三件全集；现在正式入口消费22件原版来源队列，缺效果身份必须保留并拒绝领取。迁移保留原8组、每个 choice=0..3、所有非法输入、UID/牌组/金币/HP/胜场/RNG/重复领取与状态回滚断言。每一真实选项要么按其已实现定义领取，要么被原子拒绝，随后显式跳过；不重抽或缩成已实现池。

资格和成功手势组件需要已实现遗物时，显式暂存完整22件的队列顺序，剩余身份全部保留，已消费Sozu资格场景保留21件。这些是组件状态快照，不是自然种子或获取概率证据。Black Blood 的独立资格组同时保留原seed42边界，并新增已有外部JDK向量seed65536：Mark of Pain/Calling Bell/Black Blood三项，按真实第三项核对缺starter原子拒绝。没有把Black Blood挪到队首再称自然出现。

旧“持有三件已实现遗物便耗尽整个池”已撤销：真正耗尽来源队列会回退Circlet，当前生产已实现本地circlet与计数。回归核对其可领取、无额外金币、计数1和重复拒绝；另保留显式skip。普通宝箱先真实打开，再检查所有实际遗物项，避免对空reward.relicId做空断言。

Boss UI原6组完整保留，成功领取/held gesture过期等使用上述显式完整队列组件状态；新增原seed1实际来源的Snecko Eye/Calling Bell/Cursed Key三项不可领取、可见原身份且不重抽的回归。paging核对实际商品描述与Boss通用说明的位置，不再拿旧控件布局当现状。

远端发现的 `map_chapters.lua` 旧负例把整个第三幕当不可用。现第二、第三幕都使用实际malformed encounter rawSeed，保留本组所有gesture/call/owner/重复click断言，固定拒绝run_seed_mismatch；新增原seed42合法第三幕第一房间通过同一地图gesture owner提交，核对35层、正常来源队列消费、roomGeneration与重复click拒绝。原37组均保留，wrapper据实改38。

## 实际验证

- 原Boss reward transaction七个预算片全部通过：8.777/8.645/7.660/8.484/2.452/3.530/6.589秒，无正文或旧hash锁变更。
- Boss宝箱迁移后整8组首次在原30秒完成5组后超时。仅把该文件按1–4、5–8拆为两入口；同正文各执行一次，原30秒，两片13.397/5.669秒通过。新增反变换锁保护**经审查迁移后的完整正文**，另记录接受基线原文件SHA，明确不声称错误旧oracle原样未变。
- Boss UI原6组加新源offer共7组原30秒通过，23.172秒。原Boss relic effects6组通过，9.268秒。新Boss宝箱正文锁与原PR238事务锁两项Node测试通过。
- encounter checkpoint4组14.046秒、queue12组3.263秒、formations7组0.495秒、formation Combat4组1.049秒、跨幕checkpoint3组12.575秒、药水重置2组6.963秒通过。
- runtime原10组、cross_act原12组首轮本session并发时30秒超时；停止本session并发后，同SHA、同源、同原30秒串行全部通过，23.692/27.586秒。两文件保持原样，不据此抬预算或改正文。
- map_chapters首次全量30秒完成30组后超时；第二次串行全量30秒完成34组后超时。两处改动组单独按同原30秒runner实际通过，4.617秒。**本地完整38组尚未通过**，保留完整日志，以当前SHA远端CI实际结果继续裁决；没有称为全量绿灯。

源码镜像依据、Boss行为和未实现的Time Eater/Awakened/Nemesis由此前Boss实现记录承接。没有GIL、官方导入、键鼠或实机操作，不外推自然章节通关、自然解锁或平台验收。
