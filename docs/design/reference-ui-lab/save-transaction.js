// Browser storage is not transactional. Verify every write, and restore prior
// values on failure. If restoration is also denied, report that honestly.
export function commitSave(entries,storage=localStorage){
 const previous=entries.map(([key])=>[key,storage.getItem(key)]);
 const written=[];
 try{
  for(const [key,value] of entries){storage.setItem(key,value);written.push(key);if(storage.getItem(key)!==value)throw new Error('Save read-back failed');}
 }catch(cause){
  let rollbackFailed=false;
  for(const key of written.reverse()){
   const value=previous.find(entry=>entry[0]===key)[1];
   try{if(value===null)storage.removeItem(key);else storage.setItem(key,value);if(storage.getItem(key)!==value)rollbackFailed=true;}catch{rollbackFailed=true;}
  }
  const error=new Error('Prototype save failed',{cause});error.rollbackFailed=rollbackFailed;throw error;
 }
}
