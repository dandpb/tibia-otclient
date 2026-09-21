function summarizeThing(thing)
  if not thing then
    return {}
  end
  local summary = {}
  local ok, value = callMethod(thing, "getId")
  if ok then summary.targetId = value end
  ok, value = callMethod(thing, "getName")
  if ok then summary.targetName = value end
  ok, value = callMethod(thing, "getPosition")
  if ok then summary.position = copyPosition(value) end
  ok, value = callMethod(thing, "getStackPos")
  if ok then summary.stackPos = value end
  return summary
end

function gameCopilot:actionSnapshot(action)
  local snapshot = { type = action.type }
  for _, field in ipairs({ "direction", "message", "method", "targetId", "targetName", "stackPos" }) do
    if action[field] ~= nil then snapshot[field] = action[field] end
  end
  if action.position then snapshot.position = copyPosition(action.position) end
  for key, value in pairs(summarizeThing(action.target)) do
    if snapshot[key] == nil then snapshot[key] = value end
  end
  return snapshot
end

function gameCopilot:createCommand(action, reason)
  self.commandSequence = self.commandSequence + 1
  local command = {
    id = string.format("%d-%d", now(), self.commandSequence),
    at = now(),
    updatedAt = now(),
    status = "planned",
    reason = reason or "requested",
    action = self:actionSnapshot(action)
  }
  self.session.commands = self.session.commands or {}
  table.insert(self.session.commands, command)
  while #self.session.commands > ABSOLUTE_LIMITS.maxCommands do
    table.remove(self.session.commands, 1)
  end
  return command
end

function gameCopilot:updateCommand(commandId, status, reason, api)
  if not commandId then return nil end
  for index = #self.session.commands, 1, -1 do
    local command = self.session.commands[index]
    if command.id == commandId then
      if COMMAND_STATES[status] then command.status = status end
      command.reason = reason
      command.api = api
      command.updatedAt = now()
      return command
    end
  end
  return nil
end

function gameCopilot:requestAction(action)
  if type(action) ~= "table" or not ACTION_PERMISSIONS[action.type] then
    return false, "unsupported action"
  end
  if self.pendingCommandId then
    self:updateCommand(self.pendingCommandId, "rejected", "superseded by a newer command")
  end
  local command = self:createCommand(action)
  self.pendingAction = action
  self.pendingCommandId = command.id
  self:record("command_planned", { commandId = command.id, action = command.action })

  if self.mode ~= "autonomous" then
    self:updateUi()
    self:save()
    return false, self.mode == "guide" and "guide mode only plans actions" or
        "action requires confirmation", serializableCopy(command)
  end
  self.pendingAction = nil
  self.pendingCommandId = nil
  return self:executeAction(action, false, command.id)
end
