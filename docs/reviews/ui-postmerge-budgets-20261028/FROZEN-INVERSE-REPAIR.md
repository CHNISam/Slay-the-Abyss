# PR319 frozen-UI 注册逆向补漏（本地，2026-10-28）

本修复线性接续 PR319 精确 head
`f9f9be9922d61324db81519bc876074054d7368d`，不替换 PR320，不更新远端。
原 `README.md`、`local-results.json` 及其历史结论原样保留。

## 真实阻塞与最小修复

[Quality 40766387793 / rules2 / job 123095428275](https://github.com/CHNISam/Slay-the-Abyss/actions/runs/40766387793/job/123095428275)
的原历史 presentation guard 拒绝了新增分片注册层，实际输入为
`49dcd4b8dfeb5c8fcac998e57c1a8fdc01f8f087959fa723470fcc36136cbf75`，
原冻结输入要求 `47565faaad06cbf34edf208a30d922ab4975b19a5025dc751c379ff6ed2d83a9`。

仅在 `tests/helpers/approved-ui-inverse.mjs` 的原 guard 前增加本路径精确逆向：
完整当前输入 SHA、原 1–3 范围前缀、唯一注册器、完整计数 footer 均绑定；
去除注册层后必须逐字恢复上述原 SHA，再走未改的 approved-UI/历史逆向链。
旧 before/after 身份继续有效；错误路径不能借用逆向，未知源不获授权。

`tests/approved-ui-inverse.test.mjs` 独立从原 manifest 推导期望输入，
但以原不可变 UI witness 的 hash 授权；补缺失/重复/改变注册器、默认范围、
footer、无执行调用、case body、无关漂移、缺源、错路径及 CRLF 合同。
原分片合同继续拒绝同步篡改 manifest 与无执行注册器的绕过。

## 本轮验证（Node v24.22.1）

- 原有两个 inverse 文件真实红：5 通过、3 失败，均为上述 hash 拒绝。
- 先加新组合合同再跑红：5 通过、4 失败，同一缺失逆向。
- 最终下列静态/源码/历史合同 **26/26，0 skip**，约 2.2 秒：

```sh
node --test --test-concurrency=1 \
  tests/approved-ui-inverse.test.mjs tests/approved-node-ui-refactor.test.mjs \
  tests/ui-regression-partitions.test.mjs tests/p0-presentation-inverse.test.mjs \
  tests/presentation-native-m3-contract.test.mjs tests/final-integration-source.test.mjs
```

- `npm run check:syntax`、`npm run check:network`、`npm run verify:backlog`、
  两个改动模块的 `node --check` 与 `git diff --check` 均通过。
- 26 项包含旧完整源绑定、原 26 源/58 源组合、临时历史树实际物化/删除、
  原 native-write archive/漂移负例、四项原源码恢复和 raw/JS/CI 唯一发现。
  这是静态/source contract 检查，不是重新生成 native trace。

## 保全与剩余关口

四项全部原 case/setup/seed/顺序及 8 个 Lua 入口与 PR319 head 字节一致；
各入口逆向后与 `cec690c1` 原文件逐字相等，原 Git blob/SHA 均相等。
原 manifest、golden、production、runner、worker、timings、30 秒期限均未改。
PR314 的 TASK81、ENGINEERING、verify-delivery、delivery.test 四路径仍是
`cdb08af255c57624637b576d3ccb8904fc9c7d79` 的原 blob。

本轮原日志、源码守恒脚本与冻结 SHA 收据位于执行者独立目录
`/workspace/scratch/c1a4970a76e0/pr319-frozen-inverse-evidence-20261028/`；
另一次新增测试先误以为缺失已绑定源应返回 null，原 guard 正确拒绝，
因此只修正该新测试为必须拒绝；中间日志保留。

尚须独立审查本地 child SHA、核实实际远端 head 未被他人更新，获准整合后再采
新精确 HEAD 的完整托管 Quality/inventory、当前 base 的 schema3 delivery preflight。
未重跑 raw Lua 或完整 historical trace，没有本轮 Full/native/设备性能通过声明。
官方导入、ready、同候选 PC/实体手机 UI 与性能仍是原关口；TASK4 不改状态/负责人/AC/Done。
