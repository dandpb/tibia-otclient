function gameCopilot:learnRoute(routeId, route)
  local identifier = normalizeId(routeId)
  local knowledge = self.session.knowledge
  if not identifier or type(route) ~= "table" then return false, "invalid route" end
  if not knowledge.routes[identifier] and tableSize(knowledge.routes) >= ABSOLUTE_LIMITS.maxRoutes then
    return false, "route limit reached"
  end
  local entry = serializableCopy(route) or {}
  entry.id = identifier
  entry.name = normalizeText(entry.name or identifier, ABSOLUTE_LIMITS.maxTitleLength)
  entry.waypoints = type(entry.waypoints) == "table" and entry.waypoints or {}
  entry.observations = type(entry.observations) == "table" and entry.observations or {}
  if not entry.name or #entry.waypoints > ABSOLUTE_LIMITS.maxRouteWaypoints or
      #entry.observations > ABSOLUTE_LIMITS.maxRouteObservations then return false, "invalid route" end
  for index, position in ipairs(entry.waypoints) do
    entry.waypoints[index] = copyPosition(position)
    if not entry.waypoints[index] then return false, "invalid route waypoint" end
  end
  entry.createdAt = tonumber(entry.createdAt) or now()
  entry.updatedAt = now()
  knowledge.routes[identifier] = entry
  self:record("route_learned", { routeId = identifier })
  self:save()
  return true, serializableCopy(entry)
end

function gameCopilot:learnObservation(observationId, observation)
  local identifier = normalizeId(observationId)
  local observations = self.session.knowledge.observations
  if not identifier or type(observation) ~= "table" then return false, "invalid observation" end
  if not observations[identifier] and tableSize(observations) >= ABSOLUTE_LIMITS.maxLearnedObservations then
    return false, "observation limit reached"
  end
  local entry = serializableCopy(observation) or {}
  entry.id = identifier
  entry.text = normalizeText(entry.text, ABSOLUTE_LIMITS.maxTextLength)
  if not entry.text then return false, "invalid observation" end
  if entry.position then entry.position = copyPosition(entry.position) end
  entry.createdAt = tonumber(entry.createdAt) or now()
  entry.updatedAt = now()
  observations[identifier] = entry
  self:record("observation_learned", { observationId = identifier })
  self:save()
  return true, serializableCopy(entry)
end

function gameCopilot:record(eventType, data)
  table.insert(self.session.events, {
    at = now(),
    type = eventType,
    data = serializableCopy(data) or {}
  })
  while #self.session.events > ABSOLUTE_LIMITS.maxEvents do
    table.remove(self.session.events, 1)
  end
end
