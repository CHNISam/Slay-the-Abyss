"""Stage a portable, hash-verified evidence slice. Does not change tasks or docs.

Original inputs remain untouched. Candidate GILs and the complete high-frequency
capture stay local; their exact original paths and hashes are committed in the
manifest. Selected screenshots remain original, unmodified bytes.
"""
import argparse, datetime, gzip, hashlib, json, pathlib, shutil

ROOT=pathlib.Path(r'F:\New folder')
ART=ROOT/'.artifacts/m1-closeout-20261024'
RUN_ID='ced168e4-7e7a-4699-97b4-4873610e0c41'
RUN=ART/'live/playtests'/RUN_ID
STAGE=ROOT/'.artifacts/m1-live-package/stage/docs/evidence/m1-live-20261024'
parser=argparse.ArgumentParser()
parser.add_argument('--require-final-reviews',action='store_true')
args=parser.parse_args()
STAGE.mkdir(parents=True,exist_ok=True)

def digest(data):return hashlib.sha256(data).hexdigest()
def readjson(path):return json.loads(path.read_text(encoding='utf-8-sig'))
def writejson(name,value):
    path=STAGE/name;path.parent.mkdir(parents=True,exist_ok=True)
    path.write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
    return path

sources=[];included=[]
def source(path,role,copy_to=None,compress=False):
    path=path.resolve();raw=path.read_bytes()
    item={'sourcePath':str(path),'sourceSha256':digest(raw),'sourceBytes':len(raw),'role':role,'runId':RUN_ID}
    if copy_to:
        target=STAGE/copy_to;target.parent.mkdir(parents=True,exist_ok=True)
        target.write_bytes(gzip.compress(raw,compresslevel=9,mtime=0) if compress else raw)
        packaged=target.read_bytes()
        if compress:
            assert gzip.decompress(packaged)==raw
            item['packagedEncoding']='gzip of exact original bytes'
        else:assert packaged==raw
        item.update({'packagedPath':copy_to,'packagedSha256':digest(packaged),'packagedBytes':len(packaged)})
        included.append(item)
    assert path.read_bytes()==raw, f'Input changed during packaging: {path}'
    sources.append(item);return item

source(pathlib.Path(__file__),'Exact workspace packaging script; stages files only and does not change tasks or operate the game','build-package.py')

result_path=ART/'live/verified-probe-status-final.json'
result=readjson(result_path)['result']['structuredContent']
status=readjson(RUN/'status.json')
assert result['runId']==RUN_ID
assert status['result']['verifiedOfficialSave']=='1073741841'
assert result['state']=='succeeded' and any(s['step']=='log-collected' and s.get('found') for s in status['steps'])
assert result['log']['file'] and result['log']['printCount']>0 and not result['log']['truncated']

raw_inventory=[]
for p in sorted(RUN.iterdir(),key=lambda p:p.name):
    if p.is_file():
        item=source(p,'Complete raw run directory inventory; retained locally')
        raw_inventory.append({**item,'fileName':p.name})
writejson('raw-run-inventory.json',{'runId':RUN_ID,'rawDirectory':str(RUN.resolve()),'allOriginalsRetainedLocally':True,'files':raw_inventory})
source(RUN/'request.json','Exact runner request','run-request.json')
source(RUN/'status.json','Exact terminal runner status; succeeded is execution completion, not visual acceptance','run-status.json')
source(RUN/'session-log.gia','Exact newly collected official raw session log','session-log.gia')
source(result_path,'Exact MCP final status with decoded prints and expectation checks','run-final-result.json.gz',True)
writejson('log-decoded.json',{'runId':RUN_ID,'sourceRawGia':next(x for x in sources if x['sourcePath']==str((RUN/'session-log.gia').resolve())),'decoderResultSource':str(result_path.resolve()),'decoderResultSha256':digest(result_path.read_bytes()),'log':result['log'],'expectations':result['expectations'],'scope':'MCP decoded log and self-reported expectation results; screenshot review is separate.'})

for path,role,dest,compress in [
    (ART/'unified-candidate.json','Frozen diagnostic build metadata','candidate.json',False),
    (ART/'preview-live-provenance-review.json','Independent official script/UI identity audit','provenance-review.json',False),
    (ART/'live/official-1841-script-readback.json','Exact official43-module script readback','official-script-readback.json.gz',True),
    (ART/'live/official-1841-ui-readback.json','Exact full official UI readback','official-ui-readback.json.gz',True),
    (ART/'unified-entry-evidence.json','Fixture offline-entry provenance; not native visual proof','fixture-offline-entry.json',False),
]:
    source(path,role,dest,compress)

candidate=readjson(ART/'unified-candidate.json')
for label in ['normal','candidate']:
    p=pathlib.Path(candidate[label]['path']);entry=source(p,'Frozen '+label+' GIL retained locally')
    assert entry['sourceSha256']==candidate[label]['sha256']
provenance=readjson(ART/'preview-live-provenance-review.json')
p=pathlib.Path(provenance['officialImportSnapshot']['file']);item=source(p,'Exact exported official save1841 snapshot retained locally')
assert item['sourceSha256']==provenance['officialImportSnapshot']['sha256']
for item in candidate['diagnosticChanges']:
    record=source(pathlib.Path(item['path']),'Frozen diagnostic source module','fixture/'+pathlib.Path(item['path']).name)
    assert record['sourceSha256']==item['sha256']

for name in ['exact-damage-negative.log','exact-damage-negative.lua','exact-damage-red.log','integer-resources-red-corrected.log','status-help-red.log']:
    source(ROOT/'.artifacts/m1-live-sprint'/name,'Existing local negative/red regression evidence. Not a new run of an older native client.','historical-red/'+name)
problem_reference=ROOT/'.worktrees/m1-closeout-integration/docs/backlog-details/TASK-10.7.md'
if problem_reference.exists():source(problem_reference,'Original user-reported damage-range problem and prior local implementation notes','historical-red/TASK-10.7-original-problem.md')
for name in ['hp-animation-red-final.log','hp-animation-green.log','hp-animation-regressions.log']:
    if (ART/name).exists():source(ART/name,'Later HP-animation fix local regression only. Does not change the failed candidate identity or prove a second native run.','later-fix-local-only/'+name)

review_inputs=[('status',ART/'status-live-review.json'),('statusLog',ART/'status-live-log-review.json'),('preview',ART/'preview-live-review.json'),('combat',ART/'combat-live-review.json'),('block',ART/'block-live-review.json')]
reviews={};selection={}
def find_images(value,owner):
    if isinstance(value,dict):
        path=value.get('file',value.get('sourcePath',value.get('path')))
        if isinstance(path,str) and pathlib.Path(path).suffix.lower() in ['.jpg','.jpeg','.png']:
            p=pathlib.Path(path)
            if not p.is_absolute():p=ART/p
            if p.is_file() and p.resolve().is_relative_to(RUN.resolve()):
                record=selection.setdefault(str(p.resolve()),{'path':p,'reviewReferences':[],'expectedSha256':value.get('sha256')})
                record['reviewReferences'].append({'review':owner,**{k:v for k,v in value.items() if k not in ['file','path','sourcePath','sha256']}})
        for item in value.values():find_images(item,owner)
    elif isinstance(value,list):
        for item in value:find_images(item,owner)
for label,path in review_inputs:
    if path.exists():
        review=readjson(path);reviews[label]=review
        source(path,'Exact independent '+label+' visual/log review','reviews/'+path.name)
        find_images(review,label)
if args.require_final_reviews:
    assert 'status' in reviews and 'statusLog' in reviews and 'preview' in reviews,'Final status/log/preview reviews not available'
    assert not any('PENDING' in str(reviews[n].get('logGate',{}).get('status','')).upper() for n in ['status','preview']),'A final reviewer still marks the current log gate pending'
for name in ['00-log-subscribed.jpg','545-end.jpg']:
    p=RUN/name
    if p.exists():selection.setdefault(str(p.resolve()),{'path':p,'reviewReferences':[{'purpose':'Actual log subscription' if name.startswith('00') else 'Run end context; not acceptance'}]})
screen_index=[]
for _,item in sorted(selection.items(),key=lambda kv:kv[1]['path'].name):
    record=source(item['path'],'Original screenshot explicitly selected by an independent reviewer','screens/'+item['path'].name)
    if item.get('expectedSha256'):assert record['sourceSha256']==item['expectedSha256']
    screen_index.append({**record,'reviewReferences':item['reviewReferences']})
writejson('selected-screens.json',{'runId':RUN_ID,'originalUnmodifiedScreenshots':True,'screenshots':screen_index})

summary={
    'runId':RUN_ID,'candidateSource':candidate['sourceCommit'],'candidateSha256':candidate['candidate']['sha256'],
    'officialSaveId':'1073741841','fixtureOnly':True,
    'runnerTerminalState':status['state'],'decodedPrintCount':result['log']['printCount'],
    'runnerExpectations':result['expectations'],'visualAcceptanceIsSeparate':True,
    'reviewAvailability':{label:path.exists() for label,path in review_inputs},
    'statusReviewerRecommendation':reviews.get('status',{}).get('acceptanceRecommendation'),
    'previewReviewerRecommendations':reviews.get('preview',{}).get('acceptanceRecommendations'),
    'originalProblemAndRedEvidence':{'originalProblem':'historical-red/TASK-10.7-original-problem.md','rawRegressions':['historical-red/'+name for name in ['exact-damage-negative.log','exact-damage-negative.lua','exact-damage-red.log','integer-resources-red-corrected.log','status-help-red.log']],'scope':'Original problem and prior local red/negative regression artifacts. This live package did not run an old native client to manufacture a new red result.'},
    'task4_1':{'status':'FAIL_CURRENT_CANDIDATE','finding':'Live diagnostic run revealed flying-card animation covering the HP area. A production fix and a separately identified second candidate/run are required; this old run cannot certify the new fix.','review':'reviews/block-live-review.json' if 'block' in reviews else 'PENDING_BLOCK_REVIEW_RECORD','reviewerRecommendation':reviews.get('block',{}).get('acceptanceRecommendation'),'laterFixNotCertifiedByThisRun':reviews.get('block',{}).get('minimalFix')},
    'wholeMilestone1':'NOT_CLOSED_BY_PACKAGING','wholeUiGate':'NOT_CERTIFIED_BY_PACKAGING',
    'limitations':['Explicitly injected status/block/preview fixture, not natural acquisition or a normal complete game.','Synthetic callback events are not physical mouse or phone gesture proof.','43 of54 individual status detail phases were pictured in the initial visual review; missing phases remain listed.','Runner succeeded and4/4 printed expectations do not override the real HP occlusion failure.','A later production fix has a different identity and needs separate new native verification.'],
    'selectedOriginalScreenshots':len(screen_index),'completeRawFileCount':len(raw_inventory),
}
writejson('report.json',summary)
report_md=f'''# M1 本轮实机证据 · 2026-10-24

固定诊断副本 `01dd39274f42ddaccf73e68fdf7bcbe4986919f96c297e94e6d6c4483bef297a`，源码 `{candidate['sourceCommit']}`，官方存档 `1073741841`，真实 run `{RUN_ID}`。本轮已取得客户端日志订阅、原生画面及新日志：837条显式打印、ready、九状态完成和预览阶段均可核对，运行器期待4/4满足。运行器完成不等于全部画面验收通过。

| 项目 | 本轮独立审核结论与范围 |
|---|---|
| TASK-11.1 九状态 | 九类名称/数值、叠层与触发衰减或永久保持的详情画面通过诊断范围审核；54状态记录及54次整局只读断言具备新日志。实际保存43/54个独立详情阶段，缺失11项在审核原件逐项列出。 |
| TASK-10.7 确定数值 | 14个预览阶段记录未瞄准4、普通目标4、易伤目标6、取消恢复4、多段、群攻基础值、费用及整数资源；仅一次真实出牌，日志确认一次伤害6。历史真实红/负控证据已关联，并非本轮重跑旧原生客户端。 |
| TASK-10.8 意图与说明 | 原生画面确认复合行动、状态承担者及完整说明；悬停/长按/点按使用明确标记的生产回调合成事件，不认证物理鼠标或手机输入路由。 |
| TASK-4.1 格挡/血条 | **旧候选未通过**：飞行防御牌暂时覆盖角色HP数字及血条。运行器成功、无显式脚本fault不能覆盖该可见缺陷。后续修复必须另列新候选与二轮实机；本包不认证新修复。 |

状态主审核：[status-live-review.json](reviews/status-live-review.json)，新日志逐项核对：[status-live-log-review.json](reviews/status-live-log-review.json)。预览审核：[preview-live-review.json](reviews/preview-live-review.json)。实际失败、原帧与后续修复边界：[block-live-review.json](reviews/block-live-review.json)。这些是原审核记录的原始字节副本，打包器没有更改任务或勾选验收项。

原问题与既有红证据见 [TASK-10.7原问题记录](historical-red/TASK-10.7-original-problem.md)、[确定值旧红日志](historical-red/exact-damage-red.log)、[负控日志](historical-red/exact-damage-negative.log)、[整数资源旧红日志](historical-red/integer-resources-red-corrected.log)及[说明入口旧红日志](historical-red/status-help-red.log)。后续飞牌修复的本地红绿/回归保存在 `later-fix-local-only/`；它们不会改变旧run的失败结论。

官方43模块读回和完整UI身份复核见 [provenance-review.json](provenance-review.json)。原始官方读回以无损gzip保存；`manifest.json`分别记录原始SHA256与压缩文件SHA256。官方嵌入源码匹配不是独立的活动外部Lua运行文件审计。新会话原始日志为 [session-log.gia](session-log.gia)，MCP解码原件与期待结果来自 `run-final-result.json.gz`，可读导出为 [log-decoded.json](log-decoded.json)。

精选原始截图共{len(screen_index)}张，未改变像素，索引与原件路径见 [selected-screens.json](selected-screens.json)。全部高频帧保留在本地原run目录，其逐文件绝对路径和hash见 [raw-run-inventory.json](raw-run-inventory.json)；没有把数百帧全部提交。本包所有文件的完整性校验见 [package-integrity.json](package-integrity.json)，打包复现脚本为 [build-package.py](build-package.py)。

本轮使用明确的注入夹具与暂停的格挡时间线，不证明自然获取、正常敌人AI、整局通关、物理手机输入、实时节奏或音效。状态详情可读不代表常驻状态chip附近数字全部可读，主UI审核仍需保留该限制；全UI正式门禁和M1整体完成不由本证据包宣告。
'''
(STAGE/'report.md').write_text(report_md,encoding='utf-8',newline='\n')
writejson('manifest.json',{'schemaVersion':1,'createdAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),'runId':RUN_ID,'officialSaveId':'1073741841','rootSourceDirectory':str(ART.resolve()),'stagedEvidenceDirectory':str(STAGE.resolve()),'selectionPolicy':'Only original images explicitly referenced by independent status/preview/combat reviews plus subscription/end context. Complete raw directory is retained locally and hash-inventoried. No screenshot pixels changed.','inputs':sources,'packagedOriginals':included,'note':'Manifest SHA covers original byte files. gzip SHA separately identifies the exact compressed package; decompression returns the original source hash. Derived report/log-index files carry their source identities separately.'})
readme='''# 2026-10-24 live diagnostic evidence

This package records run `ced168e4-7e7a-4699-97b4-4873610e0c41`, official save1841 and diagnostic candidate01dd3927. `report.json` separates execution, log expectations and visual review. It does not update task acceptance.

The old candidate fails the HP-occlusion requirement: flying-card animation covers the HP area. A later fix must be verified in a new candidate/run. This package must not be used as proof of that fix.

`manifest.json` records absolute original paths, original SHA256 and package paths/hashes. Official readback and full MCP status are losslessly gzip-compressed originals. `session-log.gia` is the current raw log; `log-decoded.json` is derived from the identified MCP response. `selected-screens.json` maps unchanged original frames to reviewer observations. `raw-run-inventory.json` hashes the complete local run directory; the high-frequency raw frames remain local.

Review files preserve their authors' exact stated scope, including missing frames or pending decisions. Fixture injection and synthetic callbacks do not certify natural acquisition, physical phone input or full-game acceptance. Runner completion and printed expectations do not prove every visual requirement passed.
'''
(STAGE/'README.md').write_text(readme,encoding='utf-8',newline='\n')
(STAGE/'.gitattributes').write_text('# Preserve every original evidence byte on Windows checkouts.\n* -text\n',encoding='utf-8',newline='\n')
integrity=[{'file':str(p.relative_to(STAGE)).replace('\\','/'),'sha256':digest(p.read_bytes()),'bytes':p.stat().st_size} for p in sorted(STAGE.rglob('*')) if p.is_file() and p.name!='package-integrity.json']
writejson('package-integrity.json',{'runId':RUN_ID,'files':integrity,'scope':'Every packaged file except this integrity file itself; original source hashes additionally live in manifest.json.'})
print(json.dumps({'stage':str(STAGE),'files':len(list(STAGE.rglob('*'))),'selectedScreenshots':len(screen_index),'packageBytes':sum(p.stat().st_size for p in STAGE.rglob('*') if p.is_file()),'reviews':list(reviews),'currentPrints':result['log']['printCount']},ensure_ascii=False))
