North = "north"
NorthEast = "northeast"
East = "east"
SouthEast = "southeast"
South = "south"
SouthWest = "southwest"
West = "west"
NorthWest = "northwest"
GameThingQuickLoot = 1
unpack = table.unpack or unpack

player = {}
walkCalls = 0
attackCalls = 0
lootCalls = 0
corpseOpenCalls = 0
talkCalls = 0
questLogCalls = 0
questLineCalls = 0
nowMillis = 100000
persistedFiles = {}
persistedProfile = nil
persistedSession = nil
directories = {}
modules = { game_quickloot = {} }
g_game = {
  isOnline = function() return true end,
  getLocalPlayer = function() return player end,
  isAttacking = function() return false end,
  isFollowing = function() return false end,
  getAttackingCreature = function() return nil end,
  walk = function() walkCalls = walkCalls + 1 return true end,
  attack = function() attackCalls = attackCalls + 1 end,
  use = function() corpseOpenCalls = corpseOpenCalls + 1 end,
  getFeature = function() return true end,
  sendQuickLoot = function() lootCalls = lootCalls + 1 end,
  talk = function() talkCalls = talkCalls + 1 end,
  requestQuestLog = function() questLogCalls = questLogCalls + 1 end,
  requestQuestLine = function() questLineCalls = questLineCalls + 1 end
}
g_clock = { millis = function() return nowMillis end }
g_resources = {
  directoryExists = function(path) return directories[path] == true end,
  makeDir = function(path) directories[path] = true return true end,
  fileExists = function(path) return persistedFiles[path] ~= nil end,
  readFileContents = function(path) return persistedFiles[path] end,
  writeFileContents = function(path, contents) persistedFiles[path] = contents return true end
}
json = {
  encode = function(value)
    return value and value.allowWalking ~= nil and "PROFILE" or "SESSION"
  end,
  decode = function(contents)
    return contents == "PROFILE" and persistedProfile or persistedSession
  end
}
g_logger = { error = function() end }
g_settings = {
  getNode = function() return {} end,
  setNode = function() end,
  save = function() end
}
connect = function() end
disconnect = function() end

for _, sourceFile in ipairs({
  "game_copilot.lua",
  "game_copilot_runtime.lua",
  "game_copilot_lifecycle.lua",
  "game_copilot_controls.lua",
  "game_copilot_commands.lua",
  "game_copilot_routes.lua",
  "game_copilot_actions.lua",
  "game_copilot_quests.lua",
  "game_copilot_learning.lua",
  "game_copilot_persistence.lua",
  "game_copilot_ui.lua"
}) do
  dofile("modules/game_copilot/" .. sourceFile)
end

passed = 0
function expect(condition, message)
  if not condition then error(message, 2) end
end

function test(name, body)
  local ok, failure = pcall(body)
  if not ok then
    io.stderr:write("FAIL " .. name .. ": " .. tostring(failure) .. "\n")
    os.exit(1)
  end
  passed = passed + 1
  print("PASS " .. name)
end

function resetCopilot()
  walkCalls = 0
  attackCalls = 0
  lootCalls = 0
  corpseOpenCalls = 0
  talkCalls = 0
  questLogCalls = 0
  questLineCalls = 0
  nowMillis = 100000
  player.getPosition = function() return { x = 100, y = 100, z = 7 } end
  player.isWalkLocked = function() return false end
  player.canWalk = function() return true end
  player.getHealth = function() return 100 end
  player.getMaxHealth = function() return 100 end
  player.getMana = function() return 100 end
  player.getMaxMana = function() return 100 end
  player.getLevel = function() return 1 end
  player.getDirection = function() return North end
  g_game.getCharacterName = function() return "Knight 1" end
  gameCopilot.mode = "confirm"
  gameCopilot.resumeMode = "confirm"
  gameCopilot.paused = false
  gameCopilot.player = player
  gameCopilot.state = {
    online = true,
    health = { percent = 100 },
    mana = { percent = 100 }
  }
  gameCopilot.profile = {
    minimumHealthPercent = 60,
    minimumManaPercent = 20,
    allowWalking = true,
    allowCombat = true,
    allowLoot = true,
    allowNpcTalk = true
  }
  gameCopilot.lastDispatchAt = {}
  gameCopilot.session = {
    events = {}, commands = {}, quests = {}, observations = 0,
    knowledge = { routes = {}, observations = {} }
  }
  gameCopilot.window = nil
  gameCopilot.pendingAction = nil
  gameCopilot.pendingCommandId = nil
  gameCopilot.commandSequence = 0
end
