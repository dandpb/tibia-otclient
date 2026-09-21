function gameCopilot:requestWalk(direction)
  local normalized = tostring(direction or ""):lower()
  if not DIRECTIONS[normalized] then return false, "unknown direction" end
  return self:requestAction({ type = "walk", direction = normalized })
end

function gameCopilot:startRouteRecording(routeId, routeName)
  if self.activeRouteRecording then return false, "route recording is already active" end
  local identifier = normalizeId(routeId)
  local name = normalizeText(routeName or routeId, ABSOLUTE_LIMITS.maxTitleLength)
  local player = currentPlayer()
  local position = player and copyPosition(player:getPosition()) or nil
  if not identifier or not name or not position then return false, "invalid route recording" end
  self.activeRouteRecording = {
    id = identifier,
    name = name,
    waypoints = { position },
    observations = {}
  }
  self:record("route_recording_started", { routeId = identifier, position = position })
  self:updateUi()
  return true
end

function gameCopilot:stopRouteRecording()
  local route = self.activeRouteRecording
  self.activeRouteRecording = nil
  if not route then return false, "route recording is not active" end
  if #route.waypoints < 2 then
    self:record("route_recording_rejected", { routeId = route.id, reason = "too few waypoints" })
    self:updateUi()
    return false, "route needs at least two waypoints"
  end
  local learned, result = self:learnRoute(route.id, route)
  self:updateUi()
  return learned, result
end

function gameCopilot:startRoutePlayback(routeId)
  if self.routePlayback then return false, "route playback is already active" end
  if self.mode ~= "autonomous" or self.paused then return false, "autonomous mode is required" end
  local identifier = normalizeId(routeId)
  local route = identifier and self.session.knowledge.routes[identifier] or nil
  local player = currentPlayer()
  local position = player and copyPosition(player:getPosition()) or nil
  if not route or type(route.waypoints) ~= "table" or #route.waypoints < 2 or not position then
    return false, "learned route is unavailable"
  end
  local currentIndex
  for index, waypoint in ipairs(route.waypoints) do
    if positionsEqual(position, waypoint) then
      currentIndex = index
      break
    end
  end
  if not currentIndex or currentIndex >= #route.waypoints then
    return false, "stand on a non-final learned waypoint to replay the route"
  end
  self.routePlayback = { routeId = identifier, index = currentIndex + 1 }
  self:record("route_playback_started", { routeId = identifier, waypoint = currentIndex })
  self:updateUi()
  return self:advanceRoutePlayback()
end

function gameCopilot:advanceRoutePlayback()
  local playback = self.routePlayback
  if not playback or playback.expectedPosition then return false, "route playback is not ready" end
  local route = self.session.knowledge.routes[playback.routeId]
  if not route or playback.index > #route.waypoints then
    return self:stopRoutePlayback("route completed")
  end
  local player = currentPlayer()
  local current = player and copyPosition(player:getPosition()) or nil
  local target = copyPosition(route.waypoints[playback.index])
  local direction = directionBetween(current, target)
  if not direction then
    self:stopRoutePlayback("next learned waypoint is not adjacent")
    return false, "next learned waypoint is not adjacent"
  end
  playback.expectedPosition = target
  local dispatched, reason = self:requestWalk(direction)
  if not dispatched then
    self:stopRoutePlayback(reason)
    return false, reason
  end
  self:record("route_step_dispatched", {
    routeId = playback.routeId, waypoint = playback.index, direction = direction
  })
  self:updateUi()
  return true, "route step dispatched"
end

function gameCopilot:stopRoutePlayback(reason)
  local playback = self.routePlayback
  self.routePlayback = nil
  if not playback then return false, "route playback is not active" end
  self:record("route_playback_stopped", { routeId = playback.routeId, reason = reason or "manual" })
  self:updateUi()
  self:save()
  return true, reason or "manual"
end
