local count=0
debug.sethook(function() count=count+1 end,'',1000)
dofile(assert(os.getenv('FIXTURE')))
debug.sethook()
print('LUA_INSTRUCTIONS_1000',count)
