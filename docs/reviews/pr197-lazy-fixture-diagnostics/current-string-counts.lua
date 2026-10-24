local native=tostring
local count=0
tostring=function(v) count=count+1;return native(v) end
dofile(assert(os.getenv('FIXTURE')))
print('TOSTRING_CALLS',count)
