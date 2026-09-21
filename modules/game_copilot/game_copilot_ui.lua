function gameCopilot:updateUi()
  if not self.window then
    return
  end
  local status = self.window:recursiveGetChildById("status")
  local character = self.window:recursiveGetChildById("character")
  local position = self.window:recursiveGetChildById("position")
  local mode = self.window:recursiveGetChildById("mode")
  local pending = self.window:recursiveGetChildById("pending")
  local profileThresholds = self.window:recursiveGetChildById("profileThresholds")
  local quests = self.window:recursiveGetChildById("quests")
  local routeStatus = self.window:recursiveGetChildById("routeStatus")
  local sessionLog = self.window:recursiveGetChildById("sessionLog")
  local state = self.state or {}

  status:setText(state.online and "Status: observing" or "Status: offline")
  character:setText("Character: " .. tostring(state.character or self.profile.character or "-"))
  local p = state.position
  position:setText(p and string.format("Position: %d, %d, %d", p.x, p.y, p.z) or "Position: -")
  mode:setText("Mode: " .. self:getMode())
  if self.pendingAction then
    local detail = self.pendingAction.direction or self.pendingAction.method or self.pendingAction.message or ""
    pending:setText("Pending action: " .. self.pendingAction.type .. " " .. detail)
  else
    pending:setText("Pending action: none")
  end
  profileThresholds:setText(string.format("Safety: %d%% HP / %d%% mana",
    self.profile.minimumHealthPercent, self.profile.minimumManaPercent))
  local combinedQuests = {}
  for questId, quest in pairs(self.session.serverQuestState or {}) do
    combinedQuests[questId] = { completed = quest.completed == true }
  end
  for questId, quest in pairs(self.session.quests or {}) do
    combinedQuests[questId] = { completed = quest.status == "completed" }
  end
  local questCount, activeQuestCount = 0, 0
  for _, quest in pairs(combinedQuests) do
    questCount = questCount + 1
    if not quest.completed then activeQuestCount = activeQuestCount + 1 end
  end
  quests:setText(questCount == 0 and "Quests: none" or
    string.format("Quests: %d (%d active / %d done)",
      questCount, activeQuestCount, questCount - activeQuestCount))
  local commands = self.session.commands or {}
  local latestCommand = commands[#commands]
  if latestCommand and latestCommand.reason == "cancelled by emergency" then
    sessionLog:setText("Emergency: walk cancelled")
  elseif latestCommand then
    sessionLog:setText(string.format("Last: %s %s",
      latestCommand.action and latestCommand.action.type or "action",
      latestCommand.status or "unknown"))
  else
    sessionLog:setText("Last: none")
  end
  if self.activeRouteRecording then
    routeStatus:setText(string.format("Route: recording %s (%d points)",
      self.activeRouteRecording.id, #self.activeRouteRecording.waypoints))
  elseif self.routePlayback then
    routeStatus:setText(string.format("Route: replaying %s (%d)",
      self.routePlayback.routeId, self.routePlayback.index))
  elseif self.session.knowledge.routes.last_route then
    routeStatus:setText(string.format("Route: last_route learned (%d points)",
      #self.session.knowledge.routes.last_route.waypoints))
  else
    routeStatus:setText("Route: none learned")
  end
  for _, permission in ipairs({ "allowWalking", "allowCombat", "allowLoot", "allowNpcTalk" }) do
    local widget = self.window:recursiveGetChildById(permission)
    if widget and widget:isChecked() ~= (self.profile[permission] == true) then
      widget:setChecked(self.profile[permission] == true)
    end
  end
end
