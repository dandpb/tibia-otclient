gameCopilot = {}

PROFILE_DIR = "/copilot/profiles/"
SESSION_DIR = "/copilot/sessions/"
BASE_DIR = "/copilot/"
PROFILE_NAME = "knight_noob_1"
SESSION_SCHEMA_VERSION = 2
VALID_MODES = {
  guide = true,
  confirm = true,
  autonomous = true
}
ACTION_PERMISSIONS = {
  walk = "allowWalking",
  combat = "allowCombat",
  loot = "allowLoot",
  npc_talk = "allowNpcTalk"
}
ACTION_COOLDOWNS = {
  walk = 150,
  combat = 300,
  loot = 500,
  npc_talk = 1000
}
QUEST_STATES = {
  planned = true,
  active = true,
  blocked = true,
  completed = true,
  abandoned = true
}
OBJECTIVE_STATES = {
  pending = true,
  active = true,
  blocked = true,
  completed = true,
  skipped = true
}
COMMAND_STATES = {
  planned = true,
  dispatched = true,
  rejected = true
}
ABSOLUTE_LIMITS = {
  maxCommands = 200,
  maxEvents = 200,
  maxQuests = 100,
  maxObjectivesPerQuest = 64,
  maxEvidencePerQuest = 256,
  maxNotesPerQuest = 128,
  maxRoutes = 128,
  maxRouteWaypoints = 512,
  maxRouteObservations = 256,
  maxLearnedObservations = 512,
  maxIdLength = 80,
  maxTitleLength = 160,
  maxTextLength = 1000,
  maxNpcMessageLength = 120,
  maxCombatDistance = 8,
  maxLootDistance = 1,
  maxNpcDistance = 4
}
DIRECTIONS = {
  north = North,
  northeast = NorthEast,
  east = East,
  southeast = SouthEast,
  south = South,
  southwest = SouthWest,
  west = West,
  northwest = NorthWest
}
DIRECTION_OFFSETS = {
  north = { x = 0, y = -1 },
  northeast = { x = 1, y = -1 },
  east = { x = 1, y = 0 },
  southeast = { x = 1, y = 1 },
  south = { x = 0, y = 1 },
  southwest = { x = -1, y = 1 },
  west = { x = -1, y = 0 },
  northwest = { x = -1, y = -1 }
}

function onGameStart()
  gameCopilot:onGameStart()
end

function onGameEnd()
  gameCopilot:onGameEnd()
end

function onPlayerPositionChange()
  gameCopilot:onPositionChange()
end

function onPlayerHealthChange()
  gameCopilot:onHealthChange()
end

function onPlayerManaChange()
  gameCopilot:onManaChange()
end

function onPlayerStatesChange()
  gameCopilot:onStatesChange()
end

function onQuestLog(questList)
  gameCopilot:onQuestLog(questList)
end

function onQuestLine(questId, questMissions)
  gameCopilot:onQuestLine(questId, questMissions)
end

function onClientEvent(eventType, ...)
  gameCopilot:onClientEvent(eventType, ...)
end

function toggleCopilot()
  gameCopilot:toggle()
end

function requestContextCombat(_, _, _, creature)
  gameCopilot:requestCombat(creature)
end

function requestContextLoot(_, lookThing, useThing)
  local target = useThing and useThing:isLyingCorpse() and useThing or lookThing
  gameCopilot:requestLoot(target, "quick_loot")
end

function requestContextNpcTalk(_, _, _, creature)
  gameCopilot:requestNpcTalk(creature, "hi")
end

function isMonsterContext(_, _, _, creature)
  return creature ~= nil and creature:isMonster()
end

function isCorpseContext(_, lookThing, useThing)
  return (useThing ~= nil and useThing:isLyingCorpse()) or
      (lookThing ~= nil and lookThing:isLyingCorpse())
end

function isNpcContext(_, _, _, creature)
  return creature ~= nil and creature:isNpc()
end

function safeFilePart(value)
  return tostring(value or "unknown"):lower():gsub("[^%w_-]", "_")
end

function now()
  return os.time()
end

function monotonicMillis()
  if g_clock and type(g_clock.millis) == "function" then
    local ok, value = pcall(g_clock.millis)
    if ok and type(value) == "number" then
      return value
    end
  end
  return now() * 1000
end

function clamp(value, minimum, maximum)
  value = tonumber(value)
  if not value then
    return minimum
  end
  return math.max(minimum, math.min(maximum, value))
end

function normalizeText(value, maximumLength)
  if type(value) ~= "string" then
    return nil
  end
  local text = value:gsub("^%s+", ""):gsub("%s+$", "")
  if text == "" or #text > maximumLength or text:find("%c") then
    return nil
  end
  return text
end

function normalizeId(value)
  local identifier = normalizeText(value, ABSOLUTE_LIMITS.maxIdLength)
  if not identifier or not identifier:match("^[%w_.:-]+$") then
    return nil
  end
  return identifier
end

function tableSize(value)
  local count = 0
  for _ in pairs(value or {}) do
    count = count + 1
  end
  return count
end
