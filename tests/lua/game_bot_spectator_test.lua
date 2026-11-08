-- luajit tests/lua/game_bot_spectator_test.lua
-- The real character-selection path runs with an offline network stub.
dofile('modules/client_entergame/characterlist.lua')
local function upvalue(fn, wanted, value)
  for i=1,100 do
    local name=debug.getupvalue(fn,i)
    if not name then break end
    if name==wanted then debug.setupvalue(fn,i,value);return end
  end
  error('Missing upvalue '..wanted)
end
local connections, loads, unloads, errors = 0, 0, 0, 0
local loaded, unloadFails, present = true, false, true
local module = {
  isLoaded=function() return loaded end,
  unload=function() unloads=unloads+1;if not unloadFails then loaded=false end end,
  load=function() loads=loads+1;loaded=true end,
}
g_modules={getModule=function(name) assert(name=='game_bot');if present then return module end end}
g_game={isOnline=function() return false end,loginWorld=function()
  if G.account:lower()=='@cast' and present then assert(not loaded,'spectator must not start owner client bot') end
  connections=connections+1
end}
g_settings={set=function(name) assert(name=='last-used-character' or name=='last-used-world') end}
connect=function() end
tr=function(text) return text end
displayCancelBox=function() return {} end
displayErrorBox=function() errors=errors+1 end
g_logger={warning=function() end}
local selected={worldHost='127.0.0.1',worldPort=7172,worldName='Fixture',characterName='Fixture'}
upvalue(CharacterList.doLogin,'characterList',{getFocusedChild=function() return selected end})
upvalue(CharacterList.doLogin,'charactersWindow',{hide=function() end})
CharacterList.hide=function() end
local function login(account) G={account=account};CharacterList.doLogin() end

login('owner')
assert(connections==1 and loaded and loads==0 and unloads==0)
login('@cast')
assert(connections==2 and not loaded and unloads==1)
login('@CAST')
assert(connections==3 and not loaded and unloads==1)
login('owner')
assert(connections==4 and loaded and loads==1)
-- A bot disabled by the user must not be enabled by an ordinary login.
loaded=false
login('owner')
assert(connections==5 and not loaded and loads==1)
present=false
login('@cast')
assert(connections==6)
present=true;loaded=true;unloadFails=true
login('@cast')
assert(connections==6 and errors==1,'failed suspension must stop before game connection')
print('PASS: cast suspends local automation before connecting; owner settings, user-disabled and absent modules preserved')
