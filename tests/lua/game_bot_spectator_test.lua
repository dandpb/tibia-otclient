-- luajit tests/lua/game_bot_spectator_test.lua [optional baseline bot.lua]
-- Real bot/profile entry points, sandboxed with no network or credential access.
local function loadSandbox(path)
    local environment = setmetatable({}, {__index = _G})
    local chunk = assert(loadfile(path))
    setfenv(chunk, environment)()
    return environment
end

local function setUpvalue(fn, wanted, value)
    for i = 1, 100 do
        local name = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then
            debug.setupvalue(fn, i, value)
            return
        end
    end
    error('Missing upvalue: ' .. wanted)
end

local bot = loadSandbox(arg[1] or 'mods/game_bot/bot.lua')
local profiles = loadSandbox('mods/client_profiles/profiles.lua')
local executions, loads, saves, clears, writes = 0, 0, 0, 0, 0
local enabled, status
local settings = {['Grizzle Alyronia_1500'] = {enabled = true, config = 'legacy'}}
g_game = {
    isOnline = function() return true end,
    getCharacterName = function() return 'Grizzle Alyronia' end,
    getClientVersion = function() return 1500 end,
}
g_settings = {
    getNode = function() return settings end,
    getNumber = function() return 1 end,
    setNode = function() writes = writes + 1 end,
    save = function() writes = writes + 1 end,
}
g_resources = {
    directoryExists = function() return true end,
    fileExists = function() return false end,
}
modules = {
    game_bot = bot,
    game_topbar = {refresh = function() end},
    game_actionbar = {refresh = function() end},
    game_mainpanel = {getButton = function() return nil end},
}
setUpvalue(bot.refresh, 'enableButton', {setOn = function(_, value) enabled = value end})
setUpvalue(bot.refresh, 'statusLabel', {
    setOn = function() end,
    setText = function(_, value) status = value end,
})
setUpvalue(bot.refresh, 'configList', {
    options = {{text = 'legacy'}},
    setCurrentOption = function() end,
    getCurrentOption = function() return {text = 'legacy'} end,
})
bot.save = function() saves = saves + 1 end
bot.clear = function() clears = clears + 1 end
bot.loadConfigsList = function() loads = loads + 1 end
bot.executeBot = function() executions = executions + 1; return {} end
bot.check = function() end
-- Keep the real post-startup height update in the normal-owner path.
for i = 1, 100 do
    local name, value = debug.getupvalue(bot.refresh, i)
    if not name then break end
    if name == 'updateBotTabsHeight' then
        setUpvalue(value, 'botTabs', {
            updateLayout = function() end,
            getLayout = function() return nil end,
            isOn = function() return false end,
            setHeight = function() end,
        })
        break
    end
end

for _, account in ipairs({'@cast', '@CAST'}) do
    G = {account = account}
    bot.refresh()
    profiles.collectiveReload()
    assert(executions == 0, 'spectator startup/profile refresh must not execute client bot scripts')
    assert(loads == 0 and saves == 0 and writes == 0, 'spectator must preserve saved owner state')
    assert(clears > 0 and enabled == false, 'spectator must leave local automation inactive')
    assert(status and status:find('spectator', 1, true), 'spectator status must explain inactivity')
    assert(settings['Grizzle Alyronia_1500'].enabled == true, 'owner preference must stay enabled')
end

G = {account = 'owner'}
bot.refresh()
assert(executions == 1 and enabled == true, 'normal owner must retain enabled automation')
settings['Grizzle Alyronia_1500'].enabled = false
bot.refresh()
assert(executions == 1 and enabled == false, 'user-disabled automation must stay disabled')
g_game.isOnline = function() return false end
G = nil
bot.refresh()
assert(executions == 1, 'offline refresh must remain inactive')
print('PASS: spectator startup/profile callbacks stay available without executing scripts or changing owner settings')
