package.path='src/lua/?.lua;build/lua/?.lua;'..package.path
local S=require('abyss_snapshot')
local key,child={},{};key.child=child;child.parent=key;key.self=key
local root={[false]={enabled=false},[key]=false,one={field=false},two={field={v=3}}}
local disabled=root[false];local oldField=root.two.field
local restore,owner=S.capture(root,child)
assert(restore==owner and S.ownedRestore(owner,{})==nil)
assert(S.ownedRestore(owner,child)==restore and S.ownedRestore(owner,child)==nil)
root[false]={};root[key]=true;key.child=nil;child.parent=nil;key.self=nil
root.one.field={changed=true};root.two.field=false;disabled.enabled=true;oldField.v=-1
restore()
assert(root[false]==disabled and disabled.enabled==false,'[SNAPSHOT_KEY_TYPES] false key/value retains identity')
assert(root[key]==false and key.child==child and child.parent==key and key.self==key,'[SNAPSHOT_KEY_TYPES] table key cycle restores')
assert(root.one.field==false and root.two.field==oldField and oldField.v==3,'[SNAPSHOT_KEY_TYPES] repeated scalar keys retain value types')
-- Every capture has its own save and key cache. A later graph uses the same
-- field names with reversed scalar/table values; the former restore stays live.
local newField={enabled=false};root.one.field=newField;root.two.field=false
local newer,newOwner=S.capture(root,newField)
root.one.field=nil;newField.enabled=true;root.two.field={unexpected=true}
newer()
assert(root.one.field==newField and newField.enabled==false and root.two.field==false,'[SNAPSHOT_KEY_TYPES] next capture sees new graph')
assert(S.release(newOwner)and not S.release(newOwner)and S.ownedRestore(newOwner,newField)==nil)
restore()
assert(root.one.field==false and root.two.field==oldField,'[SNAPSHOT_KEY_TYPES] previous capture remains independent')
for k in pairs(root)do assert(k==false or k==key or k=='one'or k=='two','[SNAPSHOT_KEY_TYPES] no cache state enters saved graph')end
print('SNAPSHOT_KEY_TYPES_PASS 1')
