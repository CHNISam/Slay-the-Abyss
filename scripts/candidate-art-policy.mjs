import {readFileSync} from 'node:fs';
import {join} from 'node:path';
import {artFeatureKeys,normalizeArtFeatures,verifyArtFeatureReceipt} from './art-features.mjs';

// A build flag selects an implementation; it cannot grant product permission.
// Re-enabling deferred artwork requires an explicit, reviewed policy change.
export function assertCandidateArtPolicy(flags,{root=process.cwd()}={}) {
 const policy=JSON.parse(readFileSync(join(root,'data/release/candidate-art-policy.json'),'utf8'));
 if(policy?.schemaVersion!==1||Object.keys(policy).some(key=>!['schemaVersion','disabledFeatures'].includes(key))
  ||!policy.disabledFeatures||typeof policy.disabledFeatures!=='object'||Array.isArray(policy.disabledFeatures)
  ||Object.entries(policy.disabledFeatures).some(([key,reason])=>!artFeatureKeys.includes(key)||typeof reason!=='string'||!reason.trim()))
  throw Error('Invalid candidate artwork policy');
 const effective=normalizeArtFeatures(flags);
 for(const [key,reason]of Object.entries(policy.disabledFeatures))
  if(effective[key])throw Error(`CANDIDATE_ART_DISABLED: ${key}: ${reason}`);
}

export function assertCandidateArtReceipt(receipt,options) {
 assertCandidateArtPolicy(verifyArtFeatureReceipt(receipt.artFeatures),options);
 if(receipt.artFeatures.flags.cards===false&&(receipt.readyCardArt?.enabled||receipt.nativeCardArt))
  throw Error('Candidate card artwork payload conflicts with disabled feature');
}
