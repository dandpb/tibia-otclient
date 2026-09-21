function gameCopilot.init()
  local self = gameCopilot
  self.window = nil
  self.button = nil
  self.player = nil
  self.state = { online = false }
  self.mode = "guide"
  self.resumeMode = "guide"
  self.paused = false
  self.pendingAction = nil
  self.pendingCommandId = nil
  self.commandSequence = 0
  self.lastDispatchAt = {}
  self.activeRouteRecording = nil
  self.routePlayback = nil
  self.profile = createProfile("Knight Noob 1")
  self.session = createSession()

  local settings = g_settings.getNode("gameCopilot") or {}
  if VALID_MODES[settings.mode] then
    self.mode = settings.mode
    self.resumeMode = settings.mode
  end

  self.button = modules.game_mainpanel.addToggleButton(
    "gameCopilotButton",
    tr("Knight Copilot"),
    "/images/options/button_taskboard",
    function()
      self:toggle()
    end,
    false,
    1007
  )
  self.button:setOn(false)

  self.window = g_ui.loadUI("game_copilot", modules.game_interface.getLeftPanel())
  local content = self.window and self.window:getChildByIndex(1)
  local scroll = self.window and self.window:getChildById("gameCopilotScroll")
  if content and scroll then
    content:setVerticalScrollBar(scroll); scroll:setStep(20); for _, child in ipairs(content:getChildren()) do child:show() end
  end
  self.window:hide()
  g_keyboard.bindKeyDown("Ctrl+Shift+K", toggleCopilot)
  modules.game_interface.addMenuHook("gameCopilot", tr("Copilot: attack monster"),
    requestContextCombat, isMonsterContext)
  modules.game_interface.addMenuHook("gameCopilot", tr("Copilot: quick-loot corpse"),
    requestContextLoot, isCorpseContext)
  modules.game_interface.addMenuHook("gameCopilot", tr("Copilot: say hi to NPC"),
    requestContextNpcTalk, isNpcContext)

  connect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  connect(g_game, { onQuestLog = onQuestLog, onQuestLine = onQuestLine, onClientEvent = onClientEvent })

  if g_game.isOnline() then
    self:onGameStart()
  else
    self:updateUi()
  end
end

function gameCopilot.terminate()
  local self = gameCopilot
  self:save()

  if self.player then
    disconnect(self.player, {
      onPositionChange = onPlayerPositionChange,
      onHealthChange = onPlayerHealthChange,
      onManaChange = onPlayerManaChange,
      onStatesChange = onPlayerStatesChange
    })
  end

  disconnect(g_game, { onGameStart = onGameStart, onGameEnd = onGameEnd })
  disconnect(g_game, { onQuestLog = onQuestLog, onQuestLine = onQuestLine, onClientEvent = onClientEvent })
  g_keyboard.unbindKeyDown("Ctrl+Shift+K", toggleCopilot)
  modules.game_interface.removeMenuHook("gameCopilot")

  if self.window then
    self.window:destroy()
    self.window = nil
  end
  if self.button then
    self.button:destroy()
    self.button = nil
  end
end

function gameCopilot:refreshScroll()
  if not self.window then
    return
  end
  local content = self.window:getChildByIndex(1)
  if content then
    content:updateScrollBars()
    local last = content:getChildByIndex(content:getChildCount())
    if last then self.window:getChildById("gameCopilotScroll"):setMaximum(300) end
  end
end

function gameCopilot:toggle()
  if not self.window then
    return
  end
  if self.window:isVisible() then
    self.window:hide()
    self.button:setOn(false)
  else
    self.window:show()
    self.button:setOn(true)
    scheduleEvent(function() self:refreshScroll() end, 100)
    self:updateUi()
  end
end

function gameCopilot:onGameStart()
  local character = g_game.getCharacterName()
  self.player = currentPlayer()
  self.state = { online = self.player ~= nil, character = character }
  self.profile = createProfile(character)
  self.session = createSession()
  self.pendingAction = nil
  self.pendingCommandId = nil
  self.activeRouteRecording = nil
  self.routePlayback = nil
  self.lastDispatchAt = {}
  self.paused = false
  self:loadProfile()
  self:loadSession()
  self:record("login", { character = character })

  if self.player then
    connect(self.player, {
      onPositionChange = onPlayerPositionChange,
      onHealthChange = onPlayerHealthChange,
      onManaChange = onPlayerManaChange,
      onStatesChange = onPlayerStatesChange
    })
  end
  self:observe()
  self:refreshQuestLog()
  if self.window then self.window:show(); self.button:setOn(true); self:refreshScroll(); scheduleEvent(function() self:refreshScroll() end, 100) end
end

function gameCopilot:onGameEnd()
  if self.pendingCommandId then
    self:updateCommand(self.pendingCommandId, "rejected", "game session ended before dispatch")
  end
  self:record("logout", {})
  self:observe()
  self:save()

  if self.player then
    disconnect(self.player, {
      onPositionChange = onPlayerPositionChange,
      onHealthChange = onPlayerHealthChange,
      onManaChange = onPlayerManaChange,
      onStatesChange = onPlayerStatesChange
    })
  end
  self.player = nil
  self.pendingAction = nil
  self.pendingCommandId = nil
  self.activeRouteRecording = nil
  self.routePlayback = nil
  self.state.online = false
  self:updateUi()
end

function gameCopilot:observe()
  local player = currentPlayer()
  if not player then
    self.state = { online = false }
    self:updateUi()
    return self.state
  end

  local position = player:getPosition()
  local health = player:getHealth()
  local maxHealth = player:getMaxHealth()
  local mana = player:getMana()
  local maxMana = player:getMaxMana()

  self.state = {
    online = true,
    character = g_game.getCharacterName(),
    position = copyPosition(position),
    health = { current = health, maximum = maxHealth, percent = maxHealth > 0 and health * 100 / maxHealth or 0 },
    mana = { current = mana, maximum = maxMana, percent = maxMana > 0 and mana * 100 / maxMana or 0 },
    level = player:getLevel(),
    direction = player:getDirection(),
    inCombat = g_game.isAttacking()
  }
  self.session.observations = self.session.observations + 1
  self.session.lastState = self.state
  self:updateUi()
  return self.state
end

function gameCopilot:onPositionChange()
  if not self.player then return end
  local position = copyPosition(self.player:getPosition())
  self:record("position_change", { position = position })
  if self.activeRouteRecording then
    local waypoints = self.activeRouteRecording.waypoints
    local last = waypoints[#waypoints]
    if not positionsEqual(last, position) and #waypoints < ABSOLUTE_LIMITS.maxRouteWaypoints then
      table.insert(waypoints, position)
    end
  end
  self:observe()
  if self.routePlayback then
    if positionsEqual(position, self.routePlayback.expectedPosition) then
      self.routePlayback.index = self.routePlayback.index + 1
      self.routePlayback.expectedPosition = nil
      self:advanceRoutePlayback()
    else
      self:stopRoutePlayback("route playback deviated from the learned path")
    end
  end
end

function gameCopilot:onHealthChange()
  self:observe()
end

function gameCopilot:onManaChange()
  self:observe()
end

function gameCopilot:onStatesChange()
  self:observe()
end

function gameCopilot:onQuestLog(questList)
  self.session.serverQuestState = self.session.serverQuestState or {}
  for _, data in pairs(questList or {}) do
    local questId, questName, completed = unpack(data)
    local identifier = normalizeId(tostring(questId or ""))
    local title = normalizeText(questName, ABSOLUTE_LIMITS.maxTitleLength)
    if identifier and title then
      self.session.serverQuestState[identifier] = {
        id = identifier, title = title, completed = completed == true, updatedAt = now()
      }
    end
  end
  self:record("quest_log_observed", { count = tableSize(self.session.serverQuestState) })
  self:updateUi()
end

function gameCopilot:onQuestLine(questId, questMissions)
  local identifier = normalizeId(tostring(questId or ""))
  if not identifier then return end
  self.session.serverQuestState = self.session.serverQuestState or {}
  local entry = self.session.serverQuestState[identifier] or { id = identifier }
  entry.missions = {}
  for _, data in pairs(questMissions or {}) do
    local missionName, description, missionId = unpack(data)
    local mission = {
      id = normalizeId(tostring(missionId or "")),
      name = normalizeText(missionName, ABSOLUTE_LIMITS.maxTitleLength),
      description = normalizeText(description, ABSOLUTE_LIMITS.maxTextLength)
    }
    if mission.id and mission.name then table.insert(entry.missions, mission) end
  end
  entry.updatedAt = now()
  self.session.serverQuestState[identifier] = entry
  self:record("quest_line_observed", { questId = identifier, missionCount = #entry.missions })
end

function gameCopilot:onClientEvent(eventType, ...)
  self:record("client_event_observed", { eventType = tostring(eventType or "unknown"), data = {...} })
end
