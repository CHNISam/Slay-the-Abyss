# 遗物主名称消失：离线适配根因与受控重绘

生产源码仍为`e8eb72360d1a1e9eef015948e3b63bf09661f372`；本修复分支接续仅证据提交`af81787d`。生产`src/`、`data/`、`config/`、`scripts/`全部不改，未动背景、批准布局或字号。本次修复的是离线UI捕获和Simulator适配，不是已证实的官方客户端缺陷。

## 因果链

1. 原截图`before.sim.png`未绘出“余烬之心”，但原真实GameUI解析树中`relicPanel/row1/name`可见、文本正确，24px，290×32，位置(-30,+26)，颜色#F5D79A。
2. `scripts/native-ui-theme.mjs`生成该文字时已有`autoSize=true`、`minFontSize=14`。原`capture.lua`只保留字号/最小字号，丢失autoSize及运行时字号覆盖；原sim转换也未映射`adaptiveFontSize`，因而继承seed中false。
3. 已安装`beyond-simulator-mcp@0.5.2`的worker文本排版使用1.2倍行高，并对textbox添加`fontSize*0.25+4`块内边距；24px单行需38.8px，高于32px，固定字号模式计算出0可见行。48px高的面板标题正常，排除同色、无文本和层遮挡假设。
4. 修复捕获时保留布局autoSize及真实runtime override（特别是显式false），转换时映射为Simulator adaptiveFontSize。重新执行生产GameUI捕获及实际Simulator Host截图后，`after.sim.png`可见“余烬之心”。大小、位置、颜色和生产定义完全不改。
5. 进一步从原before.tree只给名称补autoSize=true，生成`isolated.sim.png`。`isolated-save-diff.json`记录两份save除自动编号id/guid外，唯一语义差异正是名称adaptiveFontSize false→true；名称同样出现。没有用改字号或放大框来掩盖问题。

## 证据

- `before.*`从已接受af81787d的原遗物详情证据逐字复制，保留修前PNG、解析树、转换save及回执。
- `after.*`为修正捕获/适配后真实生产Host控件的静帧。
- `isolated.*`为原解析树的单字段诊断重绘，隔离字段丢失的因果。
- 两张新PNG均经view_image实看，manual/frame0/time0、pc-16-9、1600×900。没有伪造图片或运行官方GUI。
- 回执仍含8项`fetch failed`素材警告，图标仍为红框。没有清除警告或绕过403；本次只证明文字字段适配恢复，不证明最终美术、官方导入、ready、手机触控或设备性能通过。
- 原日志格式修正位于`../m3-visual-20261031`：raw gzip完整保留原字节，LF可读文本及metadata同步更新，403 Forbidden仍在。

## 验证和复现

`tests/ui-polish-sim-text.test.mjs`先RED（生产32高名称autoSize映射缺失；runtime固定字号属性缺失），修后3/3通过，包含Lua捕获逻辑的布局fallback与runtime显式false/字号覆盖。没有增加生产规则测试或重跑重Lua整套。

```sh
npm run build:data
npm run build:ui
node scripts/map-ui-layout.mjs
node --test --test-concurrency=1 tests/ui-polish-sim-text.test.mjs
node docs/evidence/m3-relic-name-20261031/capture.mjs
ART_LAB_MCP_ENTRY=/workspace/cloud-tools/m3-sim-runtime/node_modules/beyond-simulator-mcp/dist/index.js node experiments/ui-polish-sim/sim.mjs docs/evidence/m3-relic-name-20261031 after isolated
```

`host.log`为真实捕获输出；metadata保留全部本目录文件、适配器及所用模拟器bundle SHA256。普通卡牌runtime明确关闭自动字号时仍保留false，不对所有文字强制缩小。官方名称呈现仍需真实客户端证据，但本次“名称未绘出”的离线症状已被受控实验定位并解除。
