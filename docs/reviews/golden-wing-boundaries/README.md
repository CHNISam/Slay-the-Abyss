# Golden Wing 独立测试候选

固定基线 develop@3ed8bf4b88a950c4736ec2d68e83f141d415c4db。先读 REPORT.md，再读 independent/REVIEW.md。候选仅新增 tests/lua/golden_wing_boundaries.lua；16新增、21既有测试在原生Lua5.4通过，作者8及独立5故意破坏均捕获。没有发现生产缺陷，不把负控失败叫产品bug。

TASK13.1.2保持 In Progress/@Codex；本轮只做独立复核，不认领或关闭任务。CLI缺失，未修改任务。未跑新候选完整CI/Fengari/平台，不当已合并交付。原执行者接续时需最新基线查重、保留来源、正常CI。

本分支是证据归档，禁止将它的旧生产树直接合并。只在当前独立工作区选取candidate.patch。REPRODUCE.md保留执行时本机命令，不代表使用此分支源码可复现。
