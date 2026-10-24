"""Losslessly wrap CRLF originals, preserve reviewer bytes, record user decision.

Run after build-package.py. Only files below this script's package directory are
modified. This changes evidence storage and derived summaries, never raw reviews.
"""
import datetime,gzip,hashlib,json,pathlib
P=pathlib.Path(__file__).resolve().parent
def sha(raw):return hashlib.sha256(raw).hexdigest()
def load(name):return json.loads((P/name).read_text(encoding='utf-8-sig'))
def save(name,value):(P/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8',newline='\n')
review_hashes={str(f.relative_to(P)):sha(f.read_bytes()) for f in (P/'reviews').rglob('*') if f.is_file()}
manifest=load('manifest.json');changes={};proofs=[]
for f in sorted(P.rglob('*')):
    if not f.is_file() or f.suffix.lower() in ['.gz','.jpg','.jpeg','.png','.gia']:continue
    rel=f.relative_to(P).as_posix();raw=f.read_bytes()
    if b'\r\n' not in raw:continue
    assert not rel.startswith('reviews/'),'Reviewer original must never be changed'
    assert f.resolve().is_relative_to(P)
    encoded=gzip.compress(raw,compresslevel=9,mtime=0);target=f.with_name(f.name+'.gz')
    assert target.resolve().is_relative_to(P)
    target.write_bytes(encoded);assert gzip.decompress(target.read_bytes())==raw
    changes[rel]=rel+'.gz';proofs.append({'oldPackagePath':rel,'packagedPath':rel+'.gz','originalSha256':sha(raw),'originalBytes':len(raw),'gzipSha256':sha(encoded),'gzipBytes':len(encoded),'decompressedOriginalHashVerified':True})
    f.unlink()
newly_wrapped=len(proofs)
if not proofs:proofs=json.loads(json.dumps(manifest.get('storageRepair',{}).get('files',[])))
for proof in proofs:
    if proof['oldPackagePath']==proof['packagedPath'] and proof['packagedPath'].endswith('.gz'):
        proof['oldPackagePath']=proof['packagedPath'][:-3]
for proof in proofs:changes[proof['oldPackagePath']]=proof['packagedPath']

def migrate(value):
    if isinstance(value,dict):
        old=value.get('packagedPath')
        if old in changes:
            target=P/changes[old];encoded=target.read_bytes();raw=gzip.decompress(encoded)
            assert sha(raw)==value['sourceSha256'],'Original hash must remain unchanged'
            value.update({'packagedPath':changes[old],'packagedEncoding':'gzip of exact original bytes','packagedSha256':sha(encoded),'packagedBytes':len(encoded)})
        for k,v in list(value.items()):
            if k!='storageRepair':value[k]=migrate(v)
    elif isinstance(value,list):value=[migrate(v) for v in value]
    elif isinstance(value,str) and value in changes:value=changes[value]
    return value

decision={
    'recordType':'derived user acceptance decision; original independent reviews retained unchanged',
    'recordedAt':datetime.datetime.now(datetime.timezone.utc).isoformat(),
    'runId':'ced168e4-7e7a-4699-97b4-4873610e0c41','officialSaveId':'1073741841',
    'candidateSha256':'01dd39274f42ddaccf73e68fdf7bcbe4986919f96c297e94e6d6c4483bef297a',
    'authority':'Latest explicit user instruction relayed by the coordinating agent in this conversation,2026-10-24.',
    'relayedInstruction':'正常飞牌动画短暂遮挡不算bug，不得小优化拖住M1；接受该表现并停止二轮。',
    'historicalObservationPreserved':'The initial independent block review recorded flying Defend temporarily overlapping hero HP and marked FAIL. Its original images and reviewer record remain unchanged.',
    'acceptedBehavior':'The user explicitly accepts ordinary flying-card transient overlap. It is not treated as a blocking defect or a reason to extend M1.',
    'originalBlockBadgeEvidence':{'layouts':6,'samples':108,'cancelledRestored':6,'sourceReview':'reviews/block-live-review.json','userAcceptsExistingEvidenceForOriginalRequirement':True},
    'task4_1Disposition':'ACCEPTED_BY_USER_ON_EXISTING_DIAGNOSTIC_CANDIDATE',
    'secondRound':'CANCELLED_AS_UNNECESSARY_BY_USER','newRuntimeOptimization':'Not required for M1 acceptance; its Git history is preserved by the coordinator.',
    'newNativeFixValidationClaimed':False,'originalCandidateHashChanged':False,'originalReviewerBytesChanged':False,
    'scope':'This is an acceptance decision, not a fabricated new technical test or a replacement of the historical review.'
}
save('user-acceptance-decision.json',decision)
report=migrate(load('report.json'))
report['task4_1']={'status':'ACCEPTED_BY_USER_CURRENT_CANDIDATE','historicalReviewerStatus':'FAIL','historicalFinding':'Flying Defend transiently overlaps hero HP; original independent observation and original frames retained.','historicalReview':'reviews/block-live-review.json','userDecision':'user-acceptance-decision.json','decision':'User accepts normal flying-card overlap and existing6-layout/108-sample/6-cancellation block-badge evidence; do not delay M1 for this optional optimization.','secondRound':'CANCELLED_BY_USER','newFixNativeValidationClaimed':False}
report['userAcceptanceDecision']='user-acceptance-decision.json'
report['limitations']=[line for line in report.get('limitations',[]) if 'later production fix' not in line and 'HP occlusion failure' not in line]
report['limitations'].append('Historical HP overlap observation is retained; the latest user decision accepts it. No second native-fix verification is claimed or required for this accepted behavior.')
save('report.json',report)

for name in ['report.md','README.md']:
    path=P/name;text=path.read_text(encoding='utf-8')
    for old,new in changes.items():text=text.replace(']('+old+')',']('+new+')')
    if name=='report.md':
        text=text.replace('| TASK-4.1 格挡/血条 | **旧候选未通过**：飞行防御牌暂时覆盖角色HP数字及血条。运行器成功、无显式脚本fault不能覆盖该可见缺陷。后续修复必须另列新候选与二轮实机；本包不认证新修复。 |','| TASK-4.1 格挡/血条 | **用户接受现有表现**：初次独立审核记录飞行防御牌短暂覆盖角色HP；该历史观察与原FAIL审核保留。用户最新明确正常飞牌短暂遮挡不算bug，接受原6布局/108样本/6取消的格挡角标证据，不以此小优化拖住M1，并停止二轮。 |')
        text=text.replace('它们不会改变旧run的失败结论。','这些是后续本地优化历史，不作为本次用户接受的必要条件，也不构造新的实机通过声明。')
        if '最新裁决见' not in text:text+='\n最新裁决见 [user-acceptance-decision.json](user-acceptance-decision.json)：用户接受现有正常飞牌的短暂遮挡，原格挡角标要求按既有证据验收，二轮停止。原审核FAIL及原始截图不改写；最终接受依据同时记录技术观察与用户决定。\n'
    else:
        text=text.replace('The old candidate fails the HP-occlusion requirement: flying-card animation covers the HP area. A later fix must be verified in a new candidate/run. This package must not be used as proof of that fix.','The historical independent review marked transient flying-card/HP overlap as FAIL. The user subsequently accepted this ordinary animation behavior and the existing block-badge evidence, instructed that it must not delay M1, and stopped the second round. Original reviewer bytes remain unchanged; see user-acceptance-decision.json. No new native-fix test is claimed.')
    if 'Original CRLF text artifacts are stored' not in text:text+='\nOriginal CRLF text artifacts are stored as lossless `.gz` wrappers so unchanged original bytes and hashes coexist with the normal Git whitespace check. Rebuilding uses `build-package.py` followed by `repair-byte-storage.py`; no CI rule or original hash is weakened.\n'
    path.write_text(text,encoding='utf-8',newline='\n')

manifest=migrate(manifest)
manifest['storageRepair']={'reason':'PR165 run40071788515 normal git diff --check reported CR bytes as trailing whitespace in byte-preserved original text.','policy':'Lossless gzip of original CRLF bytes. Preserve every sourceSha256 and every review original. Do not relax CI.','files':proofs,'userDecisionDerivedFile':'user-acceptance-decision.json'}
save('manifest.json',manifest)
for path,expected in review_hashes.items():assert sha((P/path).read_bytes())==expected,'Reviewer bytes changed'
save('storage-repair-verification.json',{'losslessOriginals':proofs,'reviewOriginalHashesUnchanged':review_hashes,'userDecisionIsDerived':True,'originalHashesWereNotChanged':True})
integrity=[{'file':f.relative_to(P).as_posix(),'sha256':sha(f.read_bytes()),'bytes':f.stat().st_size} for f in sorted(P.rglob('*')) if f.is_file() and f.name!='package-integrity.json']
save('package-integrity.json',{'runId':decision['runId'],'files':integrity,'scope':'Every packaged file except this integrity file itself; original source hashes additionally live in manifest.json.'})
for row in manifest['packagedOriginals']:
    data=(P/row['packagedPath']).read_bytes();raw=gzip.decompress(data) if row.get('packagedEncoding') else data
    assert sha(data)==row['packagedSha256'] and sha(raw)==row['sourceSha256'],row['packagedPath']
print(json.dumps({'losslesslyWrappedOriginals':len(proofs),'newlyWrappedThisInvocation':newly_wrapped,'reviewOriginalsUnchanged':len(review_hashes),'integrityFiles':len(integrity),'originalHashVerification':'PASS','changedPaths':changes},ensure_ascii=False))
