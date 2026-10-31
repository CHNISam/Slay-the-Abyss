# Architecture 历史合同恢复

历史候选e248c0e阶段的证明。PR436已有统一card-origin-source-inverse并更新生成战斗牌身份；本层源码不叠加到PR436，本文及原始日志只保留原结论的可恢复证据，下面的复现命令对应历史候选。当前入口与owner防绕过核验见docs/evidence/m3-completion-20261031/m3-pr436-inverse-compatibility.json。
基线 `8a5a4ad6b105e493db7b6f4d30e031c591216173`。实际CI报告的原单项在本树精确RED：当前architecture `8c6e1071…` 无法回到原PR323组合 `1b0a5505…`。新增M3卡来源层注册 `abyss_card_origin=core`、`abyss_card_origin_view=ui` 后，既有只识别评分注册的外层无法消费完整当前文件；不是历史原合同失效。

新增独立 `m3-card-origin-architecture-inverse`，完整fixture固定0b3667d架构改动及8fe95a5已审owner版本，保存前后全文、SHA-256、Git blob；fixture自身固定完整hash。仅精确当前architecture的token等价空白变体可恢复完整pre-origin原字节，再进入原有评分/PR323链。不删除JSON字段，不改原冻结hash、historical baseline、生产源码或mobile helper。两项注册的真实层级按原Git文件保留（core/UI）。

当前模块责任由helper真实源码根（import.meta URL）fresh读取两个完整owner；临时98fef历史CWD本来没有新增模块，不要求它伪造这些文件。只有识别当前已审架构时才读取新增owner，未知token不获得任何许可。重复调用不缓存责任校验，缺失/任意漂移均拒绝；前代架构本身保持幂等。

验证：原architecture两项2/2 GREEN；新增3项覆盖当前/compact/tab/CRLF、完整历史bytes及blob、删注册/错层/新增未审模块、重复键、数组顺序、字符串/转义、垃圾语法、linked缺失/追加漂移及warm后再次读取；3/3 GREEN。原architecture-source-format、真实FS token读取、pr323-accepted-source-inverse合计9/9 GREEN，真实FS结果foreign1/equivalent152/fresh-owner43，保留未知token不读linked责任、warm不隐藏真实责任变化的门禁。

原始RED和全部定向输出在 `docs/evidence/m3-architecture-inverse-20261031/`；原文gzip及hash保全，可读txt仅规范空白。Linux本轮结果不冒充Windows；CRLF仅输入模拟。未运行全套，未修改测试预算。最终集成和独立复审由主控负责。
