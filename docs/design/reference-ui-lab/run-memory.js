// Current-page preview state only. Reloading or leaving the tab loses the run.
// This is intentionally not a substitute for the unavailable native Save API.
const values=new Map();
export const runMemory={getItem:key=>values.has(key)?values.get(key):null,setItem:(key,value)=>values.set(key,String(value)),removeItem:key=>values.delete(key)};
