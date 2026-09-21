function serializableCopy(value, depth)
  depth = depth or 0
  local valueType = type(value)
  if valueType == "nil" or valueType == "string" or valueType == "boolean" then
    return value
  end
  if valueType == "number" then
    if value ~= value or value == math.huge or value == -math.huge then
      return nil
    end
    return value
  end
  if valueType ~= "table" or depth >= 8 then
    return nil
  end

  local result = {}
  local copied = 0
  for key, entry in pairs(value) do
    local keyType = type(key)
    if keyType == "string" or keyType == "number" then
      local copiedEntry = serializableCopy(entry, depth + 1)
      if copiedEntry ~= nil then
        result[key] = copiedEntry
        copied = copied + 1
        if copied >= 1024 then
          break
        end
      end
    end
  end
  return result
end

function getApi(container, name)
  if not container then
    return nil
  end
  local ok, value = pcall(function()
    return container[name]
  end)
  if ok and type(value) == "function" then
    return value
  end
  return nil
end

function callMethod(object, methodName, ...)
  if not object then
    return false, nil, "missing object"
  end
  local ok, method = pcall(function()
    return object[methodName]
  end)
  if not ok or type(method) ~= "function" then
    return false, nil, "missing method " .. methodName
  end
  local called, result = pcall(method, object, ...)
  if not called then
    return false, nil, tostring(result)
  end
  return true, result
end

function copyPosition(position)
  if not position then
    return nil
  end
  local x, y, z = tonumber(position.x), tonumber(position.y), tonumber(position.z)
  if not x or not y or not z then
    return nil
  end
  return { x = x, y = y, z = z }
end

function positionsEqual(first, second)
  first = copyPosition(first)
  second = copyPosition(second)
  return first ~= nil and second ~= nil and
      first.x == second.x and first.y == second.y and first.z == second.z
end

function directionBetween(first, second)
  first = copyPosition(first)
  second = copyPosition(second)
  if not first or not second or first.z ~= second.z then return nil end
  local deltaX, deltaY = second.x - first.x, second.y - first.y
  for direction, offset in pairs(DIRECTION_OFFSETS) do
    if deltaX == offset.x and deltaY == offset.y then return direction end
  end
  return nil
end

function positionDistance(first, second)
  first = copyPosition(first)
  second = copyPosition(second)
  if not first or not second or first.z ~= second.z then
    return math.huge
  end
  return math.max(math.abs(first.x - second.x), math.abs(first.y - second.y))
end

function appendLimited(list, value, maximum)
  if #list >= maximum then
    return false
  end
  table.insert(list, value)
  return true
end

function currentPlayer()
  if not g_game.isOnline() then
    return nil
  end
  return g_game.getLocalPlayer()
end

function createProfile(character)
  return {
    character = character or "Knight Noob 1",
    vocation = "knight",
    minimumHealthPercent = 60,
    minimumManaPercent = 20,
    allowCombat = false,
    allowLoot = false,
    allowNpcTalk = false,
    allowWalking = false
  }
end

function createSession()
  return {
    schemaVersion = SESSION_SCHEMA_VERSION,
    startedAt = now(),
    events = {},
    commands = {},
    observations = 0,
    quests = {},
    serverQuestState = {},
    knowledge = {
      routes = {},
      observations = {}
    }
  }
end
