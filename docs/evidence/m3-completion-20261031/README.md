# M3 整批离线实现与验证记录

任务范围是Backlog m-4的18项。生产范围仅岩系旅行者第一、二幕，背景策略保持；未发布、未创建版本Tag。本目录保存对应真实日志和独立复审，不替代任务AC或官方设备验收。

| 证据 | 实际结果与边界 |
| --- | --- |
| `combined-acceptance.log.gz` | 初始完整M3组合27/27：55事件四片、真实Host历史、33药水商店/普通奖励、独立同局药水链、UI来源等；为整合PR435前的源版本，最终CI另验 |
| `combined-engineering.log.gz` | 初始M3组合架构、质量、固定Luacheck、四变异杀死、原生合同通过 |
| `combined-focused.log.gz` | 原输入/来源专项13/14；唯一失败为严格中文测试读了原始“化学物X”，后643c3c0改为检查实际中文名称解析值；原失败保留 |
| `map-properties-10000.json` / `.log.gz` | 0–9999全10,000种子结构不变量通过、0错误；不冒充golden/祖先配额或平台证据 |
| `final-engineering.log.gz` | PR435与全部M3源码合成后完整工程门禁通过，固定Luacheck零新增、原四变异均被杀死、原生合同4/4 |
| `final-combination-focused.log.gz` | 最终组合首轮28/29，唯一旧帮助入口合同不符批准的隐藏规则；明确保留原失败，后续专项复验独立记录 |
| `final-parity-copy-sim-corrected.log.gz` | 旧帮助合同修复后10/10：两隐藏入口拒绝及状态不变、内部guide隔离、手柄焦点、PC恢复、中文与模拟器字号；原有效断言和30秒预算保留 |
| `final-rest-corrected.log.gz` | 公开营地休息前后UID/升级/四种来源及详情只读，标准1/1通过；两个错误休息变异被拒，独审另1/1通过 |
| `final-copy-launch.log.gz` | 中文/来源/实际首发内容35/35通过；包含先前中文唯一失败的标准包装复验 |
| `final-normal-campaign.log.gz` | 精确干净源码243ae1b下seed2正常双幕胜利、seed3与42正常战败；三局均完成且无driver阻塞 |

[正常规则逐动作轨迹](../m3-normal-campaign-20261031/summary.json)记录源码身份、driver与三个策略的SHA256、UID、牌组、资源和随机流。三局只观察到75牌中的21张自然取得、18张实际打出，不能认定全75牌自然验收。旧源码0d8a9fe的胜利与真实driver失败保留在同目录的`source-0d8a9fe/`，不改写历史。

`m3-review-*-full.json`是各领域独立审查，UI最初两个Important问题在后续4304194/85db83e后解除；`m3-review-campaign-final.json`是必选遗物模态窄审，所提新增helper指纹已在243ae1b补全；`m3-review-ci-fixes-final.json`审查435的12文件修复；`m3-review-integrated-final.json`绑定243ae1b整合源码。审查结论仅覆盖各自明确的commit和范围，不能代替最终HEAD的完整CI。

`m3-review-parity-final.json`及`m3-parity-contract-result.json`保存旧帮助合同的独立审查与阴性变异；`m3-review-simulator-final.json`确认遗物名称漏绘来自离线自动字号适配，修后真实PNG已显示名称，生产UI和背景未修改。逐任务新增勾选及仍缺的最小证据见[验收核对](backlog-acceptance.md)。

[五场景实际模拟器静帧](../m3-visual-20261031/README.md)保留纹理OSS 403及assetWarnings，不能据此判最终美术或官方PC/手机通过。当前云环境没有本轮GIL候选、官方导入/ready、实体手机或官方容量读数；相关要求仍未验收。普通代码PR按原精确HEAD CI与交付验证器集成，发布仍由既有正式候选合同约束。

## 完整CI发现后的追加收口

PR435精确a7666ca的第一次完整CI发现八张PNG缺来源登记、原型五张打击牌正文未随当前展示数据更新，另有formal开局夹具旧退出文案及Ruby Recall历史源守卫未认识新增营地来源层。均按实际失败处理，不归因于基础设施。

- 八图按原有platform-evidence类别登记精确字节与SHA256，并保留生成树/回执和权利边界；原许可测试7/7与实际检查通过，原清单/门禁未改。见`m3-review-evidence-license-final.json`。
- 原型91×8卡数组仅十处正文去掉打击标签尾句，保留可见关键词及悬停/长按说明。独审发现的新长按穿透已修并保留原Important历史；真实battle/shop处理器链10/10、Python presentation66/66通过，旧tip默认行为保持。见`m3-review-prototype-final.json`、`final-prototype-hold.log.gz`与`final-presentation.log.gz`。
- Designer真实公开Nodes全服务分支及关键拒绝/回滚，独立共享cardRandom源oracle五种子及精准少消费变异，标准组合8/8通过。`final-rng-designer.log.gz`、[事件选项审计](../../reviews/M3-EVENT-OPTIONS-AUDIT-20261031.md)、[随机消费者链](../../reviews/M3-CARD-RANDOM-CONSUMER-CHAIN-20261031.md)。不据此勾全153件效果或所有事件选项/永久hook组合。
- 新oracle字节身份用精确LF属性固定，真实Git CRLF clone控制文件确转CRLF而认证输入逐byte保持、原oracle严格再生通过；这是换行配置复现，不声称已在Windows执行。`final-card-random-checkout.log.gz`及`m3-review-card-random-final.json`保留问题与关闭记录。

最终CI及交付结果按本PR最后head单独核验，不沿用a766的Quick成功或旧完整运行。CLI经代理读取Actions收据ZIP失败时，可用GitHub连接器下载相同artifact并以GitHub digest/大小/身份认证，调用完全未改的原collect/receipt/verify函数及原CLI六项最终PR身份守卫；传输等价性审查见`m3-review-delivery-transport.json`。它不能代表CI或交付验证本身已通过。

### 后续实际CI合同关闭记录

`final-formal-campaign.log.gz`：批准的完整退出文案与不可持久化原因按真实Host精确核对，真实menu/exit两层帮助拒绝与状态守恒新增；原双幕、资源、胜败、重开与结算全部保留，标准正式入口1/1与作者外独审通过，见`m3-review-formal-final.json`。

`final-ruby-source.log.gz`：仅对已审营地来源两行作whole SHA256+Git blob双向精确逆变换，再进入原mobile/PR323链；原三营地命令冻结块hash仍由原断言核对。旧hash/archive与预算不改，未知/部分/额外漂移仍拒，标准原失败1/1与作者外独审通过，见`m3-review-camp-inverse-final.json`。

`final-architecture-inverse.log.gz`与`final-architecture-origin-negative.log.gz`：恰两新增origin/core和origin_view/ui注册按完整源及Git blob逆回，真实源码根的两个linked owner逐次新鲜验证，历史CWD不要求新增文件。原架构2/2、新严格负控3/3与作者外独审通过，旧冻结proof、baseline和JSON token/顺序/重复键防护保持，见`m3-review-architecture-inverse-final.json`及[具体证明](../../reviews/M3-ARCHITECTURE-ORIGIN-INVERSE-20261031.md)。
