function gameCopilot:profilePath()
  return PROFILE_DIR .. safeFilePart(self.profile.character or PROFILE_NAME) .. ".json"
end

function gameCopilot:sessionPath()
  return SESSION_DIR .. safeFilePart(self.profile.character or PROFILE_NAME) .. ".json"
end

function gameCopilot:loadProfile()
  if not g_resources.directoryExists(BASE_DIR) then
    g_resources.makeDir(BASE_DIR)
  end
  if not g_resources.directoryExists(PROFILE_DIR) then
    g_resources.makeDir(PROFILE_DIR)
  end
  local path = self:profilePath()
  if not g_resources.fileExists(path) then
    return
  end
  local status, profile = pcall(function()
    return json.decode(g_resources.readFileContents(path))
  end)
  if status and type(profile) == "table" then
    for _, permission in ipairs({ "allowWalking", "allowCombat", "allowLoot", "allowNpcTalk" }) do
      if type(profile[permission]) == "boolean" then
        self.profile[permission] = profile[permission]
      end
    end
    self.profile.minimumHealthPercent = clamp(profile.minimumHealthPercent, 1, 100)
    self.profile.minimumManaPercent = clamp(profile.minimumManaPercent, 0, 100)
    if type(profile.character) == "string" then
      self.profile.character = safeFilePart(profile.character)
    end
  else
    g_logger.error("[Knight Copilot] profile could not be loaded")
  end
end

function gameCopilot:loadSession()
  if not g_resources.directoryExists(BASE_DIR) then
    g_resources.makeDir(BASE_DIR)
  end
  local path = self:sessionPath()
  if not g_resources.fileExists(path) then
    return
  end
  local status, session = pcall(function()
    return json.decode(g_resources.readFileContents(path))
  end)
  if not status or type(session) ~= "table" then
    g_logger.error("[Knight Copilot] session could not be loaded")
    return
  end
  if type(session.quests) == "table" then
    for questId, quest in pairs(session.quests) do
      local normalized = normalizeQuest(questId, quest)
      if normalized then self.session.quests[normalized.id] = normalized end
    end
  end
  if type(session.events) == "table" then self.session.events = session.events end
  if type(session.commands) == "table" then self.session.commands = session.commands end
  if type(session.observations) == "number" and session.observations >= 0 then
    self.session.observations = math.floor(session.observations)
  end
  if type(session.serverQuestState) == "table" then
    self.session.serverQuestState = serializableCopy(session.serverQuestState) or {}
  end
  if type(session.lastState) == "table" then
    self.session.lastState = serializableCopy(session.lastState)
  end
  if type(session.knowledge) == "table" then
    self.session.knowledge = {
      routes = type(session.knowledge.routes) == "table" and session.knowledge.routes or {},
      observations = type(session.knowledge.observations) == "table" and session.knowledge.observations or {}
    }
  end
end

function gameCopilot:save()
  if not self.profile then
    return false
  end
  if not g_resources.directoryExists(BASE_DIR) then
    g_resources.makeDir(BASE_DIR)
  end
  if not g_resources.directoryExists(PROFILE_DIR) then
    g_resources.makeDir(PROFILE_DIR)
  end
  if not g_resources.directoryExists(SESSION_DIR) then
    g_resources.makeDir(SESSION_DIR)
  end

  local profileStatus, profileData = pcall(function()
    return json.encode(self.profile, 2)
  end)
  local sessionStatus, sessionData = pcall(function()
    return json.encode(self.session, 2)
  end)
  if not profileStatus or not sessionStatus then
    g_logger.error("[Knight Copilot] state could not be encoded")
    return false
  end
  return g_resources.writeFileContents(self:profilePath(), profileData) and
      g_resources.writeFileContents(self:sessionPath(), sessionData)
end
