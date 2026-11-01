"""Compare independent Python pool vectors with the installed JVM collections."""
import hashlib,json,subprocess,tempfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
CAT=ROOT/'data/reference/sts1-card-pools'
def main():
    registration=json.loads((CAT/'registration.json').read_text(encoding='utf-8'))
    vector=json.loads((CAT/'pools.json').read_text(encoding='utf-8'))
    pools=vector['pools']
    with tempfile.TemporaryDirectory(prefix='sts1-card-pool-jdk-') as directory:
        temp=Path(directory); tsv=temp/'cards.tsv'
        tsv.write_text(''.join('\t'.join([r['id'],r['color'],r['rarity'],r['type']])+'\n' for r in registration['registration']),encoding='utf-8')
        source=ROOT/'tools/oracles/Sts1CardPoolJdk.java'
        subprocess.run(['javac','-encoding','UTF-8','-source','8','-target','8','-d',str(temp),str(source)],capture_output=True,text=True,check=True,timeout=30)
        output=subprocess.run(['java','-cp',str(temp),'Sts1CardPoolJdk',str(tsv)],capture_output=True,text=True,check=True,timeout=30).stdout
    expected=['LIBRARY\t'+x for x in pools['libraryHashMapTraversal']]
    expected+=['CURSEMAP\t'+x for x in pools['curseLibraryHashMapTraversal']]
    expected+=['GETCURSE\t'+x for x in pools['curseLibrarySelection']]
    for rarity in ['COMMON','UNCOMMON','RARE']:
        expected+=['RED\t'+rarity+'\t'+x for x in pools['redReward'][rarity]]
        for kind in ['ATTACK','SKILL','POWER']:
            expected+=['SHOP\t'+rarity+'\t'+kind+'\t'+x for x in pools['redShopTyped'][rarity][kind]]
        expected+=['COLORLESS\t'+rarity+'\t'+x for x in pools['colorlessShopByRarity'].get(rarity,[])]
    assert output.splitlines()==expected,'Installed JVM order differs: stop rather than certify the Python model'
    version=subprocess.run(['java','-version'],capture_output=True,text=True,check=True).stderr
    result={'pass':True,'comparedEntries':len(expected),'javaVersion':version.strip(),
            'registrationSha256':vector['registrationSha256'],
            'poolsSha256':hashlib.sha256((CAT/'pools.json').read_text(encoding='utf-8').encode()).hexdigest(),
            'boundary':'Installed JVM collections execution only; bytecode targets Java8. Not original PC execution, not a JDK8 runtime run.'}
    print(json.dumps(result,ensure_ascii=False))
if __name__=='__main__':main()
