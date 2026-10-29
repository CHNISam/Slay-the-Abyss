#!/usr/bin/env python3
"""Extract existing Lua literals only; no fitting, renderer, or vendor source copy."""
import argparse, hashlib, json, re
from pathlib import Path
SOURCE_SHA='fc0e4c50c0ed03a7a790731df5f5e10076d1418db615c41784210e9677c24ce3'
JSON_SHA='808bde1065f4cb636aac13d3db5488aa67597ffb51ad578696bd7642742f3753'
def record(p):
    b=p.read_bytes()
    return {'bytes':len(b),'sha256':hashlib.sha256(b).hexdigest()}
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-lua',type=Path,required=True)
    parser.add_argument('--native-json',type=Path,required=True)
    parser.add_argument('--output',type=Path,required=True)
    parser.add_argument('--receipt',type=Path,required=True)
    a=parser.parse_args()
    assert not a.output.exists() and not a.receipt.exists(),'Use new outputs; never overwrite frozen evidence'
    assert a.output.resolve()!=a.receipt.resolve(),'Output/receipt alias'
    original=record(a.source_lua);native=record(a.native_json)
    assert original['sha256']==SOURCE_SHA,'Unapproved original Lua'
    assert native['sha256']==JSON_SHA,'Unapproved editable JSON'
    s=a.source_lua.read_text();start=s.index('local ROOT = ');end=s.index('\nlocal created = {}')
    assert start<end
    literal=s[start:end]
    assert len(re.findall(r'^\s*\{100001,',literal,re.M))==13201
    text=literal+"\nreturn {sourceSha256='"+SOURCE_SHA+"',width=480,height=270,root=ROOT,rows=ELEMENTS}\n"
    a.output.parent.mkdir(parents=True,exist_ok=True);a.receipt.parent.mkdir(parents=True,exist_ok=True)
    with a.output.open('x') as f:f.write(text)
    report={'method':'Byte-identical existing ROOT/ELEMENTS literal extraction, plus data-only return',
        'sourceLua':{'path':str(a.source_lua),**original},'nativeJson':{'path':str(a.native_json),**native},
        'literalBytes':len(literal.encode()),'literalSha256':hashlib.sha256(literal.encode()).hexdigest(),
        'output':{'path':str(a.output),**record(a.output)},'rows':13201,'fitPerformed':False,
        'originalUnchanged':record(a.source_lua)==original and record(a.native_json)==native}
    with a.receipt.open('x') as f:json.dump(report,f,ensure_ascii=False,indent=2);f.write('\n')
    print(json.dumps(report))
if __name__=='__main__':main()
