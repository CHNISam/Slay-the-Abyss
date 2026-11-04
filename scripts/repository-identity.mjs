import {createHash} from 'node:crypto';
import {isDeepStrictEqual} from 'node:util';

export const projectRepositoryId=1429751262;
const names=['CHNISam/Slay-the-Abyss','FurinyaWorks/Slay-the-Abyss'];
export const projectRepositoryMatches=(resource,name)=>names.includes(name)&&
 resource?.id===projectRepositoryId&&resource.full_name===name;
export function currentProjectRepository(query){
 const repository=JSON.parse(query('api','repositories/'+projectRepositoryId));
 if(!projectRepositoryMatches(repository,repository?.full_name))throw Error('Project repository identity is unknown or mismatched');
 return repository;
}
const metadata=repository=>({id:repository.id,full_name:repository.full_name});
export function identityWitnessValid(witness,preflight,canonical){
 try{
  return witness?.schemaVersion===1&&witness.repositoryId===projectRepositoryId&&
   names.includes(preflight?.repo)&&names.includes(canonical)&&preflight.repo!==canonical&&
   witness.originalFullName===preflight.repo&&witness.canonicalFullName===canonical&&
   typeof witness.preflightText==='string'&&/^[a-f0-9]{64}$/.test(witness.preflightSha256??'')&&
   createHash('sha256').update(witness.preflightText).digest('hex')===witness.preflightSha256&&
   isDeepStrictEqual(JSON.parse(witness.preflightText),preflight)&&
   projectRepositoryMatches(witness.aliasRepository,canonical)&&projectRepositoryMatches(witness.canonicalRepository,canonical);
 }catch{return false;}
}
export function collectIdentityWitness(preflightText,canonical,query){
 const preflight=JSON.parse(preflightText);
 if(!names.includes(preflight.repo))throw Error('Historical repository alias is not registered');
 const repository=currentProjectRepository(query);
 const alias=JSON.parse(query('api','repos/'+preflight.repo));
 const witness={schemaVersion:1,repositoryId:projectRepositoryId,originalFullName:preflight.repo,
  canonicalFullName:canonical,canonicalRepository:metadata(repository),aliasRepository:metadata(alias),
  preflightText,preflightSha256:createHash('sha256').update(preflightText).digest('hex')};
 if(!identityWitnessValid(witness,preflight,canonical))throw Error('Historical repository identity witness is invalid');
 return witness;
}
