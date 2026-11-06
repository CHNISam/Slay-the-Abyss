# 实验分支发布说明

2026-11-06 用户明确允许将实验源码、GIA 和预览材料发布到公开仓库的独立实验分支。

分支在发布时以最新 develop `dedb9ed5af52fc595031d64d3e8fd84bc908b2c8` 为父提交，仅新增本目录。README 中 `87c944f3` 是制作、反馈参数查验时的参考基线；候选本身及其验证证据没有改动。未接入新版生产 UI，不改 Sprint、Backlog、主分支或他人的文件，不合并。

交付候选 SHA256：`2fc2f87b2017e1bb1e49ce6cbb8e1a3272f9474542a8ec58c5318d3f67024dad`。本分支保留 2026-11-05 的定向 Simulator 验证与独立审查，未声称已运行新版 develop 全仓 CI。官方导入、脚本重挂、新 ready、PC 和手机仍未验证。

入口：README.md；可直接打开 sample.save.json；官方空白副本候选见 import/，导入后须手动重挂 idle.lua 到 TravelerIdleLab 根容器。
