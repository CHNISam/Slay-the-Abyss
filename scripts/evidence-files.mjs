import { readFileSync, realpathSync, statSync, writeFileSync, lstatSync, mkdirSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { relative, isAbsolute, resolve, dirname } from 'node:path';

export const sha256 = bytes => createHash('sha256').update(bytes).digest('hex');
export function inside(root, file) {
  const path = realpathSync(file), base = realpathSync(root), rel = relative(base,path);
  if (rel === '..' || rel.startsWith('..\\') || rel.startsWith('../') || isAbsolute(rel)) throw new Error(`File belongs to another root: ${file}`);
  return path;
}
export function fileRecord(file, root) {
  const path = root ? inside(root,file) : realpathSync(file);
  if (!statSync(path).isFile()) throw new Error(`Not a regular file: ${file}`);
  const bytes = readFileSync(path);
  return {path,sha256:sha256(bytes),bytes:bytes.length};
}
export function prepareOutputDirectory(root, output) {
  const path=resolve(root,output);let ancestor=path;
  while(true) {
    try{lstatSync(ancestor);break;}catch(error){if(error.code!=='ENOENT')throw error;}
    const parent=dirname(ancestor);if(parent===ancestor)throw new Error('Output has no valid root');ancestor=parent;
  }
  const realParent=inside(root,ancestor),effective=resolve(realParent,relative(ancestor,path));
  const rel=relative(realpathSync(root),effective).replaceAll('\\','/');
  if(!rel || rel==='..'||rel.startsWith('../')||isAbsolute(rel)||/^(src|data|scripts|docs|tests|tools|config|\.git)(\/|$)/.test(rel))throw new Error('Output must be outside source paths and inside the project root');
  mkdirSync(path,{recursive:true});return inside(root,path);
}
export function writeExclusive(file, value) { writeFileSync(file,JSON.stringify(value,null,2)+'\n',{flag:'wx'}); }
export function validDate(value) {
  if(typeof value!=='string')return false;
  const parts=value.match(/^(\d{4})-(\d\d)-(\d\d)T(\d\d):(\d\d):(\d\d)(?:\.\d+)?(?:Z|[+-](\d\d):(\d\d))$/);
  if(!parts)return false;
  const [year,month,day,hour,minute,second,zoneHour,zoneMinute]=parts.slice(1).map(part=>Number(part??0));
  return month>=1&&month<=12&&day>=1&&day<=new Date(Date.UTC(year,month,0)).getUTCDate()&&hour<24&&minute<60&&second<60&&zoneHour<24&&zoneMinute<60&&Number.isFinite(Date.parse(value));
}
