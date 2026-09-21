function normalizeQuest(questId, quest)
  local identifier = normalizeId(questId)
  if not identifier or type(quest) ~= "table" then return nil end
  local normalized = serializableCopy(quest) or {}
  normalized.id = identifier
  normalized.title = normalizeText(normalized.title or identifier, ABSOLUTE_LIMITS.maxTitleLength)
  normalized.state = normalized.state or normalized.status or "planned"
  if not normalized.title or not QUEST_STATES[normalized.state] then return nil end
  normalized.status = normalized.state
  normalized.progress = clamp(normalized.progress or 0, 0, 100)
  normalized.objectives = type(normalized.objectives) == "table" and normalized.objectives or {}
  normalized.evidence = type(normalized.evidence) == "table" and normalized.evidence or {}
  normalized.notes = type(normalized.notes) == "table" and normalized.notes or {}
  if #normalized.objectives > ABSOLUTE_LIMITS.maxObjectivesPerQuest or
      #normalized.evidence > ABSOLUTE_LIMITS.maxEvidencePerQuest or
      #normalized.notes > ABSOLUTE_LIMITS.maxNotesPerQuest then return nil end
  normalized.createdAt = tonumber(normalized.createdAt) or now()
  normalized.updatedAt = now()
  return normalized
end

function gameCopilot:setQuest(questId, quest)
  local normalized = normalizeQuest(questId, quest)
  if not normalized then return false, "invalid quest" end
  if not self.session.quests[normalized.id] and
      tableSize(self.session.quests) >= ABSOLUTE_LIMITS.maxQuests then
    return false, "quest limit reached"
  end
  self.session.quests[normalized.id] = normalized
  self:record("quest_updated", { questId = normalized.id, state = normalized.state })
  self:save()
  return true, serializableCopy(normalized)
end

function gameCopilot:getQuest(questId)
  return serializableCopy(self.session.quests[questId])
end

function gameCopilot:refreshQuestLog()
  if not self.state.online or type(g_game.requestQuestLog) ~= "function" then
    return false, "quest log API is unavailable"
  end
  g_game.requestQuestLog()
  self:record("quest_log_requested", {})
  return true
end

function gameCopilot:refreshQuestLine(questId)
  local numericId = tonumber(questId)
  if not numericId or numericId % 1 ~= 0 or numericId < 0 or numericId > 65535 then
    return false, "invalid quest id"
  end
  local identifier = tostring(numericId)
  if type(g_game.requestQuestLine) ~= "function" then
    return false, "quest line API is unavailable"
  end
  g_game.requestQuestLine(numericId)
  self:record("quest_line_requested", { questId = identifier })
  return true
end

function gameCopilot:setQuestState(questId, state)
  local quest = self.session.quests[questId]
  if not quest or not QUEST_STATES[state] then return false, "invalid quest state" end
  quest.state, quest.status, quest.updatedAt = state, state, now()
  if state == "completed" then quest.progress = 100 end
  self:record("quest_state_changed", { questId = questId, state = state })
  self:save()
  return true
end

function gameCopilot:setQuestProgress(questId, progress)
  local quest = self.session.quests[questId]
  if not quest or tonumber(progress) == nil then return false, "invalid quest progress" end
  quest.progress, quest.updatedAt = clamp(progress, 0, 100), now()
  self:record("quest_progress_changed", { questId = questId, progress = quest.progress })
  self:save()
  return true
end

function gameCopilot:addQuestObjective(questId, objective)
  local quest = self.session.quests[questId]
  if not quest or type(objective) ~= "table" or
      #quest.objectives >= ABSOLUTE_LIMITS.maxObjectivesPerQuest then
    return false, "invalid objective or objective limit reached"
  end
  local entry = serializableCopy(objective) or {}
  entry.id = normalizeId(entry.id or ("objective-" .. tostring(#quest.objectives + 1)))
  entry.text = normalizeText(entry.text, ABSOLUTE_LIMITS.maxTextLength)
  entry.state = entry.state or entry.status or "pending"
  if not entry.id or not entry.text or not OBJECTIVE_STATES[entry.state] then
    return false, "invalid objective"
  end
  entry.status, entry.progress, entry.updatedAt = entry.state, clamp(entry.progress or 0, 0, 100), now()
  table.insert(quest.objectives, entry)
  quest.updatedAt = now()
  self:record("quest_objective_added", { questId = questId, objectiveId = entry.id })
  self:save()
  return true, serializableCopy(entry)
end

function gameCopilot:updateQuestObjective(questId, objectiveId, changes)
  local quest = self.session.quests[questId]
  if not quest or type(changes) ~= "table" then return false, "invalid objective update" end
  for _, objective in ipairs(quest.objectives) do
    if objective.id == objectiveId then
      if changes.text ~= nil then
        local text = normalizeText(changes.text, ABSOLUTE_LIMITS.maxTextLength)
        if not text then return false, "invalid objective text" end
        objective.text = text
      end
      local state = changes.state or changes.status
      if state ~= nil then
        if not OBJECTIVE_STATES[state] then return false, "invalid objective state" end
        objective.state, objective.status = state, state
      end
      if changes.progress ~= nil then objective.progress = clamp(changes.progress, 0, 100) end
      if objective.state == "completed" then objective.progress = 100 end
      objective.updatedAt, quest.updatedAt = now(), now()
      self:record("quest_objective_updated", { questId = questId, objectiveId = objectiveId })
      self:save()
      return true, serializableCopy(objective)
    end
  end
  return false, "objective not found"
end

function gameCopilot:addQuestEvidence(questId, evidence)
  local quest = self.session.quests[questId]
  if not quest or #quest.evidence >= ABSOLUTE_LIMITS.maxEvidencePerQuest then
    return false, "invalid evidence or evidence limit reached"
  end
  local entry = type(evidence) == "string" and { text = evidence } or serializableCopy(evidence)
  if type(entry) ~= "table" then return false, "invalid evidence" end
  entry.text = normalizeText(entry.text, ABSOLUTE_LIMITS.maxTextLength)
  if not entry.text then return false, "invalid evidence" end
  entry.at = tonumber(entry.at) or now()
  if entry.position then entry.position = copyPosition(entry.position) end
  table.insert(quest.evidence, entry)
  quest.updatedAt = now()
  self:record("quest_evidence_added", { questId = questId, objectiveId = entry.objectiveId })
  self:save()
  return true, serializableCopy(entry)
end

function gameCopilot:addQuestNote(questId, note)
  local quest = self.session.quests[questId]
  if not quest or #quest.notes >= ABSOLUTE_LIMITS.maxNotesPerQuest then
    return false, "invalid note or note limit reached"
  end
  local text = normalizeText(type(note) == "table" and note.text or note, ABSOLUTE_LIMITS.maxTextLength)
  if not text then return false, "invalid note" end
  local entry = { at = now(), text = text }
  table.insert(quest.notes, entry)
  quest.updatedAt = now()
  self:record("quest_note_added", { questId = questId })
  self:save()
  return true, serializableCopy(entry)
end
