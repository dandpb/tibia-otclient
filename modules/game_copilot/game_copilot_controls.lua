function gameCopilot:getState()
  return self.state
end

function gameCopilot:getMode()
  return self.paused and "paused" or self.mode
end

function gameCopilot:setPermission(permission, enabled)
  local knownPermission = false
  for _, name in pairs(ACTION_PERMISSIONS) do
    if name == permission then
      knownPermission = true
      break
    end
  end
  if not knownPermission then
    return false, "unknown permission"
  end
  self.profile[permission] = enabled == true
  if not self.profile[permission] and self.pendingAction and
      ACTION_PERMISSIONS[self.pendingAction.type] == permission then
    self:updateCommand(self.pendingCommandId, "rejected", "permission was disabled")
    self.pendingAction = nil
    self.pendingCommandId = nil
  end
  self:record("permission_change", { permission = permission, enabled = self.profile[permission] })
  self:save()
  return true
end

function gameCopilot:saveFromUi()
  self:syncProfileFromUi()
  local saved = self:save()
  self:updateUi()
  return saved
end

function gameCopilot:syncProfileFromUi()
  if not self.window then
    return
  end
  for _, permission in ipairs({ "allowWalking", "allowCombat", "allowLoot", "allowNpcTalk" }) do
    local widget = self.window:recursiveGetChildById(permission)
    if widget then
      self.profile[permission] = widget:isChecked()
    end
  end
end

function gameCopilot:setMode(mode)
  if not VALID_MODES[mode] then
    return false, "invalid mode"
  end
  self.mode = mode
  self.resumeMode = mode
  self.paused = false
  if mode ~= "autonomous" and self.routePlayback then
    self:stopRoutePlayback("mode changed")
  end
  g_settings.setNode("gameCopilot", { mode = mode })
  g_settings.save()
  self:record("mode_change", { mode = mode })
  self:updateUi()
  return true
end

function gameCopilot:pause(reason)
  self.resumeMode = self.mode
  self.paused = true
  if self.pendingCommandId then
    self:updateCommand(self.pendingCommandId, "rejected", "cancelled by " .. (reason or "pause"))
  end
  self.pendingAction = nil
  self.pendingCommandId = nil
  if self.routePlayback then
    self:stopRoutePlayback("cancelled by " .. (reason or "pause"))
  end
  self:record("pause", { reason = reason or "unknown" })
  self:updateUi()
  self:save()
end

function gameCopilot:resume()
  self.paused = false
  self.mode = self.resumeMode or "guide"
  self:record("resume", { mode = self.mode })
  self:updateUi()
end

function gameCopilot:canAct(action, confirmed)
  return self:canExecuteAction(action, confirmed)
end

function gameCopilot:canExecuteAction(action, confirmed)
  local actionType = type(action) == "table" and action.type or action
  local permission = ACTION_PERMISSIONS[actionType]
  if not permission then
    return false, "unsupported action"
  end
  if actionType == "walk" and
      (type(action) ~= "table" or type(action.direction) ~= "string" or not DIRECTIONS[action.direction]) then
    return false, "unknown direction"
  end

  if self.paused or not self.state.online or not currentPlayer() then
    return false, "copilot is paused or offline"
  end
  if self.mode == "guide" then
    return false, "guide mode does not execute actions"
  end
  if self.profile[permission] ~= true then
    return false, actionType .. " is disabled in the profile"
  end
  if self.state.health and self.state.health.percent < self.profile.minimumHealthPercent then
    return false, "health safety threshold reached"
  end
  if actionType == "combat" and self.state.mana and
      self.state.mana.percent < self.profile.minimumManaPercent then
    return false, "mana safety threshold reached"
  end
  if self.mode == "confirm" and not confirmed then
    return false, "action requires explicit confirmation"
  end
  local lastDispatch = self.lastDispatchAt[actionType]
  if lastDispatch and monotonicMillis() - lastDispatch < ACTION_COOLDOWNS[actionType] then
    return false, "action rate limit reached"
  end
  return true
end
