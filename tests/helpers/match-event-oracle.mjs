// Independent integer interpretation of pinned source facts. No production Lua imports.
import {readFileSync} from 'node:fs';
const MASK=(1n<<64n)-1n;
function mix(n){n=((n^(n>>33n))*0xff51afd7ed558ccdn)&MASK;n=((n^(n>>33n))*0xc4ceb9fe1a85ec53n)&MASK;return n^(n>>33n);}
class Random {
  constructor(seed){this.a=mix((BigInt(seed)||-(1n<<63n))&MASK);this.b=mix(this.a);this.counter=0;}
  raw(){let a=this.a,b=this.b;a^=(a<<23n)&MASK;this.a=b;this.b=(a^b^(a>>17n)^(b>>26n))&MASK;return(this.b+b)&MASK;}
  int(bound){this.counter++;const n=BigInt(bound);for(;;){const bits=this.raw()>>1n,result=bits%n;if(bits-result+n-1n<1n<<63n)return Number(result);}}
  shuffle(cards){this.counter++;let java=(this.raw()^0x5deece66dn)&((1n<<48n)-1n);const bits=()=>{java=(java*0x5deece66dn+11n)&((1n<<48n)-1n);return java>>17n;};
    const index=n=>{const b=BigInt(n);if((b&(b-1n))===0n)return Number((b*bits())>>31n);for(;;){const v=bits(),r=v%b;if(v-r+b-1n<1n<<31n)return Number(r);}};
    for(let size=cards.length;size>1;size--){const j=index(size);[cards[size-1],cards[j]]=[cards[j],cards[size-1]];}}
  snapshot(){return{words:[this.a,this.b].map(v=>v.toString(16).padStart(16,'0')),counter:this.counter};}
}
export function matchVectors(){
  const facts=JSON.parse(readFileSync('data/reference/sts1-card-pools/registration.json','utf8')).registration;
  const p=JSON.parse(readFileSync('data/reference/sts1-card-pools/pools.json','utf8')).pools;
  const byId=Object.fromEntries(facts.map(c=>[c.id,c]));
  return ['ironclad','silent','defect','watcher'].map((character,index)=>{
    const seed=['42','1','-1','9223372036854775807'][index],floor=[7,18,19,20][index];
    const roomSeed=BigInt.asIntN(64,BigInt(seed)+BigInt(floor)).toString();
    const card=new Random(seed),shuffle=new Random(roomSeed),misc=new Random(roomSeed);
    const color=['RED','GREEN','BLUE','PURPLE'][index],selected=[];
    for(const rarity of ['RARE','UNCOMMON','COMMON']){const bucket=p.libraryHashMapTraversal.filter(id=>byId[id].color===color&&byId[id].rarity===rarity);selected.push(bucket[card.int(bucket.length)]);}
    const colorless=[...p.colorlessRaw];shuffle.shuffle(colorless);selected.push(colorless.find(id=>byId[id].rarity==='UNCOMMON'));
    selected.push(p.curseLibrarySelection[card.int(p.curseLibrarySelection.length)]);
    selected.push(['Bash','Neutralize','Zap','Eruption'][index]);
    const board=[...selected,...selected];misc.shuffle(board);
    return{character,seed,floor,roomSeed,selected,board,colorless,card:card.snapshot(),shuffle:shuffle.snapshot(),misc:misc.snapshot()};
  });
}
