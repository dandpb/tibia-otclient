function gameCopilot:requestCombat(target)
  return self:requestAction({ type = "combat", target = target })
end

function gameCopilot:requestLoot(target, method)
  return self:requestAction({ type = "loot", target = target, method = method or "quick_loot" })
end

function gameCopilot:requestNpcTalk(target, message)
  local normalized = normalizeText(message, ABSOLUTE_LIMITS.maxNpcMessageLength)
  if not normalized or normalized:match("^[!/#]") then
    return false, "invalid NPC message"
  end
  return self:requestAction({ type = "npc_talk", target = target, message = normalized })
end

function gameCopilot:confirmPending()
  if not self.pendingAction then
    return false, "no pending action"
  end
  local action = self.pendingAction
  local commandId = self.pendingCommandId
  self.pendingAction = nil
  self.pendingCommandId = nil
  return self:executeAction(action, true, commandId)
end

function gameCopilot:executeAction(action, confirmed, commandId)
  local command = commandId and self:updateCommand(commandId, "planned", "validating") or
      self:createCommand(action, "direct execution requested")
  commandId = command.id
  local allowed, reason = self:canExecuteAction(action, confirmed)
  if not allowed then
    self:updateCommand(commandId, "rejected", reason)
    self:record("command_rejected", { commandId = commandId, reason = reason })
    self:updateUi()
    self:save()
    return false, reason, serializableCopy(command)
  end

  local player = currentPlayer()
  local api, apiName
  if action.type == "walk" then
    local ok, value = callMethod(player, "isWalkLocked")
    if not ok then reason = "walk safety API is unavailable"
    elseif value then reason = "player walk is locked"
    else
      ok, value = callMethod(player, "canWalk")
      if not ok then reason = "walk safety API is unavailable"
      elseif not value then reason = "player cannot walk now" end
    end
    if not reason and g_game.isFollowing() then reason = "walking while following is not allowed" end
    api, apiName = getApi(g_game, "walk"), "g_game.walk"
    if not reason and not api then reason = "walk API is unavailable" end
    if not reason then
      local called, accepted = pcall(api, DIRECTIONS[action.direction])
      if not called then reason = "walk API failed"
      elseif accepted ~= true then reason = "walk command was not accepted locally" end
    end
  elseif action.type == "combat" then
    local target = action.target
    local ok, isMonster = callMethod(target, "isMonster")
    if not ok then reason = "explicit creature target is required"
    elseif not isMonster then reason = "combat is limited to monsters" end
    if not reason then
      local _, targetPosition = callMethod(target, "getPosition")
      if positionDistance(player:getPosition(), targetPosition) > ABSOLUTE_LIMITS.maxCombatDistance then
        reason = "combat target is out of safe range"
      end
    end
    if not reason and g_game.getAttackingCreature() == target then
      reason = "target is already selected; refusing to toggle attack off"
    end
    api, apiName = getApi(g_game, "attack"), "g_game.attack"
    if not reason and not api then reason = "combat API is unavailable" end
    if not reason and not pcall(api, target) then reason = "combat API failed" end
  elseif action.type == "loot" then
    local target = action.target
    local ok, isCorpse = callMethod(target, "isLyingCorpse")
    if not ok then reason = "explicit loot target is required"
    elseif not isCorpse then reason = "loot target must be a corpse" end
    if not reason then
      local _, targetPosition = callMethod(target, "getPosition")
      if positionDistance(player:getPosition(), targetPosition) > ABSOLUTE_LIMITS.maxLootDistance then
        reason = "loot target is out of safe range"
      end
    end
    if not reason and action.method == "open_corpse" then
      api, apiName = getApi(g_game, "use"), "g_game.use"
      if not api then reason = "corpse open API is unavailable"
      elseif not pcall(api, target) then reason = "corpse open API failed" end
    elseif not reason and action.method == "quick_loot" then
      local featureOk, featureEnabled = pcall(g_game.getFeature, GameThingQuickLoot)
      api, apiName = getApi(g_game, "sendQuickLoot"), "g_game.sendQuickLoot"
      if not featureOk or not featureEnabled or not modules.game_quickloot or not api then
        reason = "quick loot API or module is unavailable"
      elseif not pcall(api, 1, target) then reason = "quick loot API failed" end
    elseif not reason then
      reason = "unsupported loot method"
    end
  elseif action.type == "npc_talk" then
    local target = action.target
    local ok, isNpc = callMethod(target, "isNpc")
    if not ok then reason = "explicit NPC target is required"
    elseif not isNpc then reason = "talk target must be an NPC" end
    if not reason then
      local _, targetPosition = callMethod(target, "getPosition")
      if positionDistance(player:getPosition(), targetPosition) > ABSOLUTE_LIMITS.maxNpcDistance then
        reason = "NPC is out of safe talking range"
      elseif g_game.isAttacking() then
        reason = "NPC talk while attacking is not allowed"
      end
    end
    api, apiName = getApi(g_game, "talk"), "g_game.talk"
    if not reason and not api then reason = "NPC talk API is unavailable" end
    if not reason and not pcall(api, action.message) then reason = "NPC talk API failed" end
  end

  if reason then
    local unavailable = reason:find("unavailable", 1, true) ~= nil
    self:updateCommand(commandId, unavailable and "planned" or "rejected", reason, apiName)
    if unavailable then
      self.pendingAction = action
      self.pendingCommandId = commandId
    end
    self:record(unavailable and "command_planned" or "command_rejected",
      { commandId = commandId, reason = reason })
    self:updateUi()
    self:save()
    return false, reason, serializableCopy(command)
  end

  self.lastDispatchAt[action.type] = monotonicMillis()
  self:updateCommand(commandId, "dispatched", "client command dispatched; outcome unverified", apiName)
  self:record("command_dispatched", { commandId = commandId, api = apiName })
  self:updateUi()
  self:save()
  return true, "client command dispatched; outcome unverified", serializableCopy(command)
end
