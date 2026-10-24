"""Derived source catalogue and independent JDK8 list-bin HashMap interpretation.
No production imports or source methods are copied. JDK17 comparison is a separate check.
"""
import hashlib,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CAT=ROOT/'data/reference/sts1-card-pools'
RARITIES=['COMMON','UNCOMMON','RARE']
CURSE_EXCLUSIONS=['AscendersBane','CurseOfTheBell','Necronomicurse','Pride']

def normalized(text): return re.sub('[^a-z0-9]','',text.lower())

def string_hash(text):
    value=0
    raw=text.encode('utf-16-be')
    for i in range(0,len(raw),2):
        value=(31*value+int.from_bytes(raw[i:i+2],'big'))&0xffffffff
    return value

def hashmap_order(rows):
    buckets=[[] for _ in range(16)]
    size=0; max_chain=0; resizes=[]
    def resize():
        nonlocal buckets
        old=buckets; buckets=[[] for _ in range(2*len(old))]
        for bucket in old:
            for h,row in bucket: buckets[h&(len(buckets)-1)].append((h,row))
        resizes.append({'afterInsertionCount':size,'capacity':len(buckets)})
    for row in rows:
        h=string_hash(row['id']); h^=h>>16
        bucket=buckets[h&(len(buckets)-1)]
        assert all(old['id']!=row['id'] for _,old in bucket)
        bucket.append((h,row)); size+=1; max_chain=max(max_chain,len(bucket))
        if len(bucket)>=9:
            if len(buckets)<64: resize()
            else: raise ValueError('Treeification requires a new independent model; do not silently approximate')
        if size>len(buckets)*3//4: resize()
    return [row for bucket in buckets for _,row in bucket],{
        'capacity':len(buckets),'maximumChainDuringConstruction':max_chain,
        'treeification':False,'resizes':resizes}

def ids(rows): return [r['id'] for r in rows]
def build():
    registration=json.loads((CAT/'registration.json').read_text(encoding='utf-8'))
    rows=registration['registration']
    library,details=hashmap_order(rows)
    curse_library,curse_details=hashmap_order([r for r in rows if r['type']=='CURSE'])
    red=[r for r in library if r['color']=='RED' and r['rarity'] in RARITIES]
    colorless=[r for r in library if r['color']=='COLORLESS' and r['rarity'] not in ['BASIC','SPECIAL'] and r['type']!='STATUS']
    curse=[r for r in library if r['type']=='CURSE' and r['id'] not in CURSE_EXCLUSIONS]
    pools={
        'libraryHashMapTraversal':ids(library),
        'redReward':{rarity:ids([r for r in red if r['rarity']==rarity]) for rarity in RARITIES},
        'redShopTyped':{rarity:{kind:sorted(ids([r for r in red if r['rarity']==rarity and r['type']==kind])) for kind in ['ATTACK','SKILL','POWER']} for rarity in RARITIES},
        'colorlessRaw':ids(colorless),
        'colorlessShopByRarity':{rarity:sorted(ids([r for r in colorless if r['rarity']==rarity])) for rarity in ['UNCOMMON','RARE']},
        'curseRaw':ids(curse),
        'curseLibraryHashMapTraversal':ids(curse_library),
        'curseLibrarySelection':ids([r for r in curse_library if r['id'] not in CURSE_EXCLUSIONS]),
        'srcRed':{rarity:list(reversed(ids([r for r in red if r['rarity']==rarity]))) for rarity in RARITIES},
        'srcColorless':list(reversed(ids(colorless))),
        'srcCurse':list(reversed(ids(curse))),
        'allColorRewardByRarity':{},
        'allColorTypedByRarity':{},
    }
    for rarity in RARITIES:
        eligible=[r for r in library if r['rarity']==rarity and r['type'] not in ['CURSE','STATUS']]
        pools['allColorRewardByRarity'][rarity]={
            'beforeShuffle':list(reversed(ids(eligible))),
            'identitySelection':sorted(ids(eligible)),
            'shuffleStream':'cardRng','identityStream':'cardRng',
            'note':'One Java shuffle seed call occurs before the sorted bounded identity pick, including duplicate attempts.'}
        pools['allColorTypedByRarity'][rarity]={}
        for kind in ['ATTACK','SKILL','POWER']:
            typed=[r for r in eligible if r['type']==kind and 'HEALING' not in r['tags']]
            pools['allColorTypedByRarity'][rarity][kind]={
                'beforeShuffle':list(reversed(ids(typed))),
                'identitySelection':sorted(ids(typed)),
                'shuffleStream':'cardRandomRng','identityStream':'cardRng'}
    ordinary=[r for r in rows if r['rarity'] in RARITIES and r['type'] not in ['CURSE','STATUS']]
    by_id={r['id']:r for r in rows}
    reachable={r['id'] for r in ordinary}
    pending=list(reachable)
    while pending:
        for dependent in by_id[pending.pop()]['directCardDependencies']:
            if dependent not in reachable:
                reachable.add(dependent);pending.append(dependent)
    pools['ordinaryPoolDirectSpecialDependencies']=ids([r for r in rows if r['id'] in reachable and r['rarity']=='SPECIAL'])
    local=json.loads((ROOT/'data/cards.json').read_text(encoding='utf-8'))['cards']
    launch=json.loads((ROOT/'data/release/launch-content.json').read_text(encoding='utf-8'))['cards']
    launch_ids={x['id'] for x in launch}
    aliases={'Strike_R':'Strike','Defend_R':'Defend'}
    local_by_name={normalized(x.get('sts_name',x['id'])):x for x in local}
    def local_for(row):return local_by_name.get(normalized(aliases.get(row['id'],row['id'])))
    def coverage_row(row):
        current=local_for(row)
        return {'sourceId':row['id'],'class':row['class'],'cost':row['cost'],'type':row['type'],'rarity':row['rarity'],
                'localDefinitionId':current['id'] if current else None,
                'inRecordedLaunch':bool(current and current['id'] in launch_ids)}
    red_all=[r for r in rows if r['color']=='RED']
    missing_red=[coverage_row(r) for r in red_all if not(local_for(r) and local_for(r)['id'] in launch_ids)]
    mismatches=[]
    for row in red_all:
        current=local_for(row)
        if current:
            for key in ['cost','type','rarity']:
                a=current.get(key); b=row[key]
                if isinstance(b,str):b=b.lower()
                if a!=b:mismatches.append({'sourceId':row['id'],'localId':current['id'],'field':key,'source':b,'current':a})
    coverage={
        'localBaselineCommit':'eb4e8af42297abfc806e58835a36b044f728d028',
        'localFilesSha256':{name:hashlib.sha256((ROOT/name).read_text(encoding='utf-8').encode()).hexdigest() for name in ['data/cards.json','data/release/launch-content.json']},
        'boundary':'Definition/recorded-launch membership only; no assertion of effect support, platform or playtest acceptance.',
        'sourceRedAll':75,'sourceRedNonbasic':72,'recordedLaunchRed':sum(bool(local_for(r) and local_for(r)['id'] in launch_ids) for r in red_all),
        'redMissingFromRecordedLaunch':missing_red,
        'colorlessShop':list(map(coverage_row,[r for r in rows if r['id'] in pools['colorlessRaw']])),
        'genericCurse':list(map(coverage_row,[r for r in rows if r['id'] in pools['curseRaw']])),
        'status':list(map(coverage_row,[r for r in rows if r['type']=='STATUS'])),
        'specialRegistryNotAutomaticallyAct1Reachable':list(map(coverage_row,[r for r in rows if r['color']=='COLORLESS' and r['rarity']=='SPECIAL'])),
        'redDefinitionMetadataMismatches':mismatches,
    }
    return {
        'schemaVersion':1,'profile':'All-unlocked Ironclad, PC A0 Act1, no daily modifiers',
        'sourceCommit':registration['source']['commit'],
        'registrationSha256':hashlib.sha256((CAT/'registration.json').read_text(encoding='utf-8').encode()).hexdigest(),
        'generatorSha256':hashlib.sha256(Path(__file__).read_text(encoding='utf-8').encode()).hexdigest(),
        'hashMap':{'interpretation':'OpenJDK8 list-bin default HashMap, verified separately against installed JVM; no PC execution authentication',
                   'source':'https://github.com/openjdk/jdk8u/blob/jdk8u472-b08/jdk/src/share/classes/java/util/HashMap.java',**details},
        'curseLibraryHashMap':curse_details,
        'pools':pools},coverage

if __name__=='__main__':
    pools,coverage=build()
    for name,value in [('pools.json',pools),('coverage.json',coverage)]:
        (CAT/name).write_text(json.dumps(value,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
    print(json.dumps({'map':pools['hashMap'],'redRarityCounts':{k:len(v) for k,v in pools['pools']['redReward'].items()},
                      'missingRed':len(coverage['redMissingFromRecordedLaunch']),
                      'redMetadataMismatches':coverage['redDefinitionMetadataMismatches']}))
