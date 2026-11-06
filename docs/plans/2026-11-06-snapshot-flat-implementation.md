# 完整快照扁平存储 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 减少完整回滚快照内部容器分配，保持原公开能力和完整 raw 图语义，并降低真实 Jaw Worm 尾段成本。

**Architecture:** 每次 capture 私有持有 visited/pending、原表顺序、表结束偏移和稠密键值缓冲；每条原始键值都记录，table-key 与 table-value 继续遍历。restore 清空并恢复原表，owner 注册/单次消费/release 不变，不裁剪或缓存旧图。

**Tech Stack:** Lua5.3/Fengari0.1.5、固定Node24.18.0、现有node:test/图比较/源码投影门禁；Backlog CLI 为任务记录。

---

执行树：`feat/snapshot-flat`，设计提交 `7149e93e`，起始 develop `c20f9898`。已批准设计见 `2026-11-06-snapshot-flat-design.md`。主控拥有元数据、共享投影、配置和最终集成；实现 worker 仅写下列 snapshot 源码/新测试，独审只读。暂不发布独立Full，最终与修复主线的候选小批集成。

## Task 1：冻结 before 与完整图合同

**Files:**
- Create `tests/fixtures/snapshot-flat/before.lua`
- Create `tests/lua/snapshot_flat.lua`
- Create `tests/snapshot-flat.test.mjs`
- 必要时复用现有图编码 helper；确需新桥接时仅 `tests/helpers/snapshot-flat-vm.mjs`

1. 从设计记录的 Git blob 完整提取1956字节旧模块，校验SHA256/Git blob，不刷新oracle。
2. 在独立旧/新实例或VM中执行相同场景并比较完整图及返回/错误观察：空表、false/0/空串、添加/删除、别名/环、table-key、深图、函数值、原元表可见性、重复/嵌套恢复、有效及错误target、owner复用/跨目标/release。
3. 用真实保留容器计数建立性能RED：从restore闭包递归观察私有table/function upvalues，排除原图和全局环境；比较不同宽度原图，扁平表示的保留容器数量应不随原表数增长。配合功能测试，不能让no-op或漏子树因数量少而通过。
4. 执行旧实现，确认行为合同正常且容器增长断言失败；错误来自真实旧结构，不是环境/缺文件。

Run（在固定Node24环境）：
`node --test tests/snapshot-flat.test.mjs`

## Task 2：实现私有扁平表示

**Files:** Modify `src/lua/abyss_snapshot.lua`；测试同Task1。

保持原type/key分类及完整发现逻辑，核心存储和恢复按以下边界实现；不新增可变数据缓存：

```lua
local seen,pending={[root]=true},{root}
local originals,ends,entries={},{},{}
local top,entryCount,kind=1,0,type
local keyTables={}
while top>0 do
    local original=pending[top];pending[top]=nil;top=top-1
    originals[#originals+1]=original
    for k,v in next,original do
        entryCount=entryCount+1;entries[entryCount]=k
        entryCount=entryCount+1;entries[entryCount]=v
        local tableKey=keyTables[k]
        if tableKey==nil then tableKey=kind(k)=='table';keyTables[k]=tableKey end
        if tableKey and not seen[k] then
            seen[k]=true;top=top+1;pending[top]=k
        end
        if kind(v)=='table' and not seen[v] then
            seen[v]=true;top=top+1;pending[top]=v
        end
    end
    ends[#originals]=entryCount
end
local function restore()
    local first=1
    for index=1,#originals do
        local original=originals[index]
        for k in next,original do rawset(original,k,nil) end
        for position=first,ends[index],2 do
            rawset(original,entries[position],entries[position+1])
        end
        first=ends[index]+1
    end
end
```

1. 保持root断言；target存在时以seen作原可达性断言，原weak owner注册和返回数量/函数身份不变。
2. 运行Task1到GREEN；以真实语义负控检测漏key/value、false丢失、边界错位、跳过table-key及owner错误。
3. 运行已有snapshot/Run/Combat完整晚失败回滚合同；不新增状态字段或不可变子树排除。

## Task 3：闭合来源与回归

**Files:** 主控按现有真实消费者修对应 `tests/helpers/*snapshot*source-inverse.mjs` 及其原测试；具体路径先由只读检索确认，不创建平行来源系统。

1. 在现有完整来源入口外层登记唯一完整新模块→固定before的精确逆投影，沿用旧hash、old oracle和fresh读取。
2. LF/CRLF、部分修改、额外漂移、跨路径及重复登记均有真实拒绝证据；未知输入不获得旧身份。
3. 新JS/Lua入口在既有 `tests/ci-complete-calibration.test.mjs` 显式列为未测；历史725/1356记录、timings、worker资格、原预算和完整唯一集合不变。
4. 执行受影响旧消费者、`check:architecture`、固定静态/复杂度和关键回滚变异；共享文件由主控串行编辑。

## Task 4：真实性能与交付

**Files:** 仅必要的有界benchmark helper和原任务附件；原Jaw fixture/哈希/轮数不变。

1. 同环境交错before/after真实384轮尾段，冻结全部输入身份、2worker、1MiB输出和原30000ms aggregate；保留慢样本/失败。
2. 核对384有序轮次、16seed、rollback/untouched各一次，全部18次共享数据守卫和语义输出相等；分开snapshot、guard和总wall，避免重叠相加。
3. 无净收益就保留旧生产实现，不用计数下降冒充托管修复；有收益后完成独立完整深审。
4. 更新TASK75.7本轮证据，按风险小批集成到当前主线修复候选。精确HEAD Full、原生队列、实际squash树及push Full通过后才完成交付AC；旧失败保留。
