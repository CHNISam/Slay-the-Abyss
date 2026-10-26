"""Generate frozen-reference expectations; production Lua must independently match them.
Requires the user's original V4 agent pack. No historic variant is selected.
"""
import argparse, hashlib, importlib.util, json, sys
from pathlib import Path

def digest(p): return hashlib.sha256(p.read_bytes()).hexdigest()

def generate(pack):
    cards_path=pack/'03_data/cards_v4.json';rules_path=pack/'03_data/rules_v4.json'
    source=pack/'90_reference/original_v4/code/engine.py'
    baseline=pack/'90_reference/original_v4/source/reference_engine.py'
    spec=importlib.util.spec_from_file_location('v4_frozen_vector_source',source)
    factory=importlib.util.module_from_spec(spec);sys.modules[spec.name]=factory;spec.loader.exec_module(factory)
    engine=factory.make_engine('frozen',fast=False)
    cards=json.loads(cards_path.read_text())['cards'];rules=json.loads(rules_path.read_text())
    for card in cards:
        reference=engine.CARDS[card['id']]
        for key in ('category','requirements','base','upgrade'):
            if key in ('base','upgrade'):
                for field in ('cost','effects','exhaust'):
                    assert reference[key][field]==card[key][field],(card['id'],key,field)
            else:assert reference[key]==card[key],(card['id'],key)
    engine.CARDS={c['id']:c for c in cards}
    changes=[]
    for role in ('HT','AR','FR','RD'):
        for change in json.loads((pack/'02_characters'/role/'changes.json').read_text()):
            actual=next(c for c in cards if c['id']==change['id'])
            assert all(actual[k]==change['new'][k] for k in ('base','upgrade'))
            changes.append({'id':change['id'],'base':change['new']['base'],'upgrade':change['new']['upgrade']})
    assert len(changes)==38 and len({c['id'] for c in changes})==38
    cases=[]
    fields={'hp':'hp','block':'block','energy':'energy','healUsed':'heal_used','infuse':'infuse','chargedUsed':'empowered_charged',
        'bond':'bond','fan':'fan','fanGained':'fan_turn','mode':'mode','singer':'singer','resolve':'resolve','resolveGained':'resolve_turn',
        'musouRefunded':'musou_refunds','nextEnergy':'next_energy','nextDraw':'next_draw','nextBlock':'next_block',
        'counter':'counter','soften':'soften','relicUsed':'relic_used'}
    for card in cards:
        role=card['role']
        for upgraded in (False,True):
            for rich in (False,True):
                s=engine.new_state(role,deck=[card['id']],seed=73,enemy_hp=(200 if rich else 60,180),upgraded=upgraded)
                s.hp=40 if rich else 30;s.maximum=rules['roles'][role]['max_hp'];s.energy=3
                s.hand=[engine.CardInstance(1,card['id'],upgraded)]
                s.draw=[engine.CardInstance(100+i,role+'2-001',False) for i in range(10)]
                s.discard=[];s.exhaust=[]
                s.enemies[0].maximum=200
                if rich:
                    s.bonus=3;s.bonus_tag='any';s.soften=2;s.counter=3
                    if role=='HT':
                        s.infuse=2
                        for enemy in s.enemies:enemy.blossom=3;enemy.blossom_uses=2
                    elif role=='AR':
                        s.bond=8
                        for enemy in s.enemies:enemy.directive=2
                    elif role=='FR':
                        s.fan=12;s.mode='ousia';s.guests={k:2 for k in s.guests};s.singer=2
                        s.revelry=2;s.revelry_bonus=2;s.revelry_duration=2
                    elif role=='RD':
                        s.resolve=6;s.eye=3;s.eye_duration=2;s.musou=3;s.musou_duration=2
                else:
                    if role=='FR':s.mode='pneuma'
                    for requirement in card['requirements']:
                        for resource in ('bond','fan','resolve'):
                            if requirement.startswith(resource):setattr(s,resource,max(getattr(s,resource),int(requirement[len(resource):])))
                initial={name:getattr(s,attr) for name,attr in fields.items()}
                initial.update(enemies=[{'hp':e.hp,'maxHp':e.maximum} for e in s.enemies],guests=s.guests.copy(),eye={'uses':s.eye,'ends':s.eye_duration},musou={'uses':s.musou,'ends':s.musou_duration},
                    revelry={'uses':s.revelry,'ends':s.revelry_duration,'bonus':s.revelry_bonus},bonus={'n':s.bonus,'tag':s.bonus_tag})
                assert engine.play(s,1,0,event_id='vector'),(card['id'],upgraded,rich)
                expected={name:getattr(s,attr) for name,attr in fields.items()}
                expected.update(guests=s.guests,eye={'uses':s.eye,'ends':s.eye_duration},musou={'uses':s.musou,'ends':s.musou_duration},
                    revelry={'uses':s.revelry,'ends':s.revelry_duration,'bonus':s.revelry_bonus},bonus={'n':s.bonus,'tag':s.bonus_tag},
                    piles={name:len(getattr(s,name)) for name in ('hand','draw','discard','exhaust')},
                    enemies=[{'hp':e.hp,'block':e.block,'bloom':{'strength':e.blossom,'ticks':e.blossom_uses} if e.blossom_uses else False,
                        'directive':e.directive} for e in s.enemies])
                cases.append({'id':card['id'],'role':role,'upgraded':upgraded,'scenario':'rich' if rich else 'lean','input':initial,'expected':expected})
    return {'version':rules['version'],'cardsSha256':digest(cards_path),'rulesSha256':digest(rules_path),
        'referenceEngineSha256':digest(source),'referenceSourceSha256':digest(baseline),
        'scope':'Reference expectations only. Production tests compare real Lua queue/actors; no game/device acceptance is inferred.',
        'directChanges':changes,'cases':cases}

def lua(value):
    if isinstance(value,bool):return 'true' if value else 'false'
    if isinstance(value,str):
        assert value.isascii(), 'Expected numeric fixture strings must stay ASCII'
        return json.dumps(value,ensure_ascii=True,separators=(',',':'))
    if isinstance(value,(int,float)):
        return str(int(value)) if int(value)==value else str(value)
    if isinstance(value,list):return '{'+','.join(lua(v) for v in value)+'}'
    if isinstance(value,dict):return '{'+','.join('['+lua(k)+']='+lua(value[k]) for k in sorted(value))+'}'
    raise TypeError(type(value))

def main():
    p=argparse.ArgumentParser();p.add_argument('--pack',required=True,type=Path);p.add_argument('--out',required=True,type=Path)
    p.add_argument('--lua-directory',type=Path);a=p.parse_args()
    value=generate(a.pack.resolve());a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(value,ensure_ascii=False,separators=(',',':'))+'\n')
    if a.lua_directory:
        a.lua_directory.mkdir(parents=True,exist_ok=True)
        for role in ('ht','ar','fr','rd'):
            for level in ('base','upgrade'):
                for scenario in ('lean','rich'):
                    up=level=='upgrade'
                    shard={'version':value['version'],'cases':[c for c in value['cases'] if c['role']==role.upper() and c['upgraded']==up and c['scenario']==scenario]}
                    header="-- Generated from independently frozen V4 expectations. Do not hand-edit values.\n"
                    body="dofile('tests/lua/support/original_v4_card_cases.lua').run('%s',%s,'%s',%s)\n" % (role.upper(),str(up).lower(),scenario,lua(shard))
                    (a.lua_directory/f'original_v4_{role}_{level}_{scenario}.lua').write_text(header+body)
    print('Frozen reference expectations:',len(value['cases']))
if __name__=='__main__':main()
