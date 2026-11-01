"""Fetch fixed public source archive in memory; write only derived metadata, never Java source."""
import argparse,hashlib,http.client,io,json,re,urllib.request,zipfile
from pathlib import Path
SHA="319009d5df0a82d9fb0f23cc22322286c6a87ec0"
URL=f"https://codeload.github.com/aeubanks/sts/zip/{SHA}"
def method(text,name):
    pos=text.index("private static void "+name+"()")
    start=text.index("{",pos); depth=1; end=start+1
    while depth:
        depth+=(text[end]=="{")-(text[end]=="}"); end+=1
    return text[start+1:end-1]
def args(text):
    start=text.index("super(")+6; out=[]; current=""; depth=0; quoted=False; escape=False
    for c in text[start:]:
        if quoted:
            current+=c
            if escape: escape=False
            elif c=="\\": escape=True
            elif c=='"': quoted=False
        elif c=='"': quoted=True; current+=c
        elif c=="(": depth+=1; current+=c
        elif c==")":
            if depth==0: out.append(current.strip()); return out
            depth-=1; current+=c
        elif c=="," and depth==0: out.append(current.strip()); current=""
        else: current+=c
    raise ValueError("unterminated super")
def extract(text,name,path):
    a=args(text)
    if len(a)!=9: raise ValueError((name,"super argc",len(a),a))
    ident=re.search(r'public static final String ID = "([^"]+)";',text)
    if not ident: raise ValueError((name,"missing ID"))
    cost=a[3]
    if not re.fullmatch(r"-?\d+",cost):
        m=re.search(r"(?:static final|final static) int "+re.escape(cost)+r"\s*=\s*(-?\d+)",text)
        if not m: raise ValueError((name,"cost",cost))
        cost=m[1]
    enum=lambda x:x.rsplit(".",1)[-1]
    return {"class":name,"id":ident[1],"cost":int(cost),"type":enum(a[5]),"color":enum(a[6]),"rarity":enum(a[7]),"target":enum(a[8]),"tags":sorted(set(re.findall(r'this\.tags\.add\(AbstractCard\.CardTags\.(\w+)\)',text))),"referencedClasses":sorted(set(re.findall(r'new (\w+)\(',text))-{name}),"sourcePath":path,"sha256":hashlib.sha256(text.encode()).hexdigest()}
def main():
    p=argparse.ArgumentParser();p.add_argument("--output",required=True);ns=p.parse_args()
    for attempt in range(5):
        try:
            with urllib.request.urlopen(URL,timeout=30) as r:
                if int(r.headers.get('Content-Length','0')) > 30_000_000: raise ValueError('archive exceeds cap')
                data=r.read()
            if len(data)>30_000_000: raise ValueError('archive exceeds cap')
            z=zipfile.ZipFile(io.BytesIO(data))
            if z.testzip() is not None: raise ValueError('archive CRC failure')
            break
        except (OSError,zipfile.BadZipFile,EOFError,http.client.HTTPException):
            if attempt==4: raise
    prefix=z.namelist()[0]
    lib=z.read(prefix+"helpers/CardLibrary.java").decode()
    imports={x.rsplit(".",1)[-1]:x.replace(".","/").removeprefix("com/megacrit/cardcrawl/")+".java" for x in re.findall(r"import (com\.megacrit\.cardcrawl\.cards\.[\w.]+);",lib)}
    rows=[]
    for group in ["Red","Green","Blue","Purple","Colorless","Curse"]:
        for name in re.findall(r"CardLibrary\.add\(new (\w+)\(\)\);",method(lib,"add"+group+"Cards")):
            path=imports[name]; text=z.read(prefix+path).decode()
            row=extract(text,name,path);row["registrationIndex"]=len(rows);row["registrationGroup"]=group.lower();rows.append(row)
    ids=[x["id"] for x in rows]
    if len(set(ids))!=len(ids): raise ValueError("duplicate IDs")
    by_class={x['class']:x['id'] for x in rows}
    for row in rows:
        row['directCardDependencies']=[by_class[x] for x in row.pop('referencedClasses') if x in by_class]
    core=z.read(prefix+'core/CardCrawlGame.java').decode()
    version=re.search(r'VERSION_NUM = "([^"]+)"',core)[1]
    result={"schemaVersion":1,"source":{"repository":"aeubanks/sts","commit":SHA,"url":URL,"archiveSha256":hashlib.sha256(data).hexdigest(),"CardLibrarySha256":hashlib.sha256(lib.encode()).hexdigest(),"declaredVersion":version,"versionBoundary":"Version string from fixed decompiled source; not authentication of the original PC binary.","extractorSha256":hashlib.sha256(Path(__file__).read_text(encoding='utf-8').encode()).hexdigest(),"note":"Derived factual metadata only; archive and source bodies never written."},"registration":rows}
    out=Path(ns.output);out.parent.mkdir(parents=True,exist_ok=True);out.write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n",encoding="utf-8")
    print(json.dumps({"cards":len(rows),"groups":{g:sum(x["registrationGroup"]==g for x in rows) for g in ["red","green","blue","purple","colorless","curse"]},"output":str(out)}))
if __name__=="__main__": main()
