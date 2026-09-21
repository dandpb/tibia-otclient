dofile("modules/game_copilot/tests/game_copilot_test_fixture.lua")

test("confirmed action still respects profile permission", function()
  resetCopilot()
  gameCopilot.profile.allowWalking = false
  local allowed, reason = gameCopilot:canExecuteAction({ type = "walk", direction = "north" }, true)
  expect(allowed == false, "confirmed walk bypassed profile permission")
  expect(reason == "walk is disabled in the profile", "unexpected rejection: " .. tostring(reason))
end)

test("combat obeys the mana safety threshold", function()
  resetCopilot()
  gameCopilot.mode = "autonomous"
  gameCopilot.state.mana.percent = 19
  local allowed, reason = gameCopilot:canExecuteAction({ type = "combat" }, false)
  expect(allowed == false, "combat ignored the mana threshold")
  expect(reason == "mana safety threshold reached", "unexpected rejection: " .. tostring(reason))
end)

test("quest log observations remain separate from local quest notes", function()
  resetCopilot()
  gameCopilot.session.quests.local_note = { id = "local_note", title = "Local note" }
  gameCopilot:onQuestLog({ { 42, "The First Quest", true } })
  expect(gameCopilot.session.quests.local_note ~= nil, "server observation replaced local notes")
  expect(gameCopilot.session.serverQuestState["42"].completed == true, "server quest was not observed")
end)

test("confirm mode plans first and dispatches the exact pending walk once", function()
  resetCopilot()
  local planned, reason = gameCopilot:requestWalk("north")
  expect(planned == false and reason == "action requires confirmation", "walk was not held for confirmation")
  expect(walkCalls == 0, "walk ran before confirmation")
  local dispatched = gameCopilot:confirmPending()
  expect(dispatched == true, "confirmed walk was not dispatched")
  expect(walkCalls == 1, "confirmed walk did not run exactly once")
  expect(gameCopilot.pendingAction == nil, "pending action was not cleared")
end)

test("emergency pause cancels a queued action", function()
  resetCopilot()
  gameCopilot:requestWalk("east")
  gameCopilot:pause("emergency")
  expect(gameCopilot.pendingAction == nil, "emergency pause left an action queued")
  expect(gameCopilot.pendingCommandId == nil, "emergency pause left a command queued")
  expect(gameCopilot.session.commands[1].status == "rejected", "cancelled command was not rejected")
end)

test("autonomous target actions dispatch only explicit valid targets", function()
  resetCopilot()
  gameCopilot.mode = "autonomous"
  local monster = {
    isMonster = function() return true end,
    getPosition = function() return { x = 101, y = 100, z = 7 } end
  }
  local corpse = {
    isLyingCorpse = function() return true end,
    getPosition = function() return { x = 100, y = 101, z = 7 } end
  }
  local npc = {
    isNpc = function() return true end,
    getPosition = function() return { x = 99, y = 100, z = 7 } end
  }
  expect(gameCopilot:requestCombat(monster) == true and attackCalls == 1, "combat target was not dispatched")
  expect(gameCopilot:requestLoot(corpse, "quick_loot") == true and lootCalls == 1, "loot target was not dispatched")
  expect(gameCopilot:requestNpcTalk(npc, "hi") == true and talkCalls == 1, "NPC target was not dispatched")
end)

test("quest parser requests valid lines and rejects malformed identifiers", function()
  resetCopilot()
  local requested, reason = gameCopilot:refreshQuestLine("42")
  expect(requested == true and reason == nil, "valid quest id was not requested")
  expect(questLineCalls == 1, "native quest line API was not called once")
  local rejected, rejection = gameCopilot:refreshQuestLine("bad id")
  expect(rejected == false, "malformed quest id reached the native API")
  expect(rejection == "invalid quest id", "unexpected malformed-id rejection: " .. tostring(rejection))
  expect(questLineCalls == 1, "native quest line API was called for malformed id")
end)

test("learned route records movement and replays it autonomously", function()
  resetCopilot()
  expect(gameCopilot:startRouteRecording("last_route", "Last route") == true, "route recording did not start")
  player.getPosition = function() return { x = 100, y = 99, z = 7 } end
  gameCopilot:onPositionChange()
  local stopped, route = gameCopilot:stopRouteRecording()
  expect(stopped == true and #route.waypoints == 2, "recorded route did not retain both positions")
  player.getPosition = function() return { x = 100, y = 100, z = 7 } end
  gameCopilot.state.position = player.getPosition()
  gameCopilot.mode = "autonomous"
  expect(gameCopilot:startRoutePlayback("last_route") == true, "route playback did not start")
  expect(walkCalls == 1, "route playback did not dispatch its first step")
end)

test("guide mode plans without dispatching and resume restores the prior mode", function()
  resetCopilot()
  gameCopilot.mode = "guide"
  local planned, reason = gameCopilot:requestWalk("north")
  expect(planned == false and reason == "guide mode only plans actions", "guide mode executed instead of planning")
  expect(walkCalls == 0, "guide mode dispatched a walk")
  gameCopilot:pause("manual")
  expect(gameCopilot:getMode() == "paused", "manual pause did not enter paused state")
  gameCopilot:resume()
  expect(gameCopilot:getMode() == "guide", "resume did not restore guide mode")
end)

print(string.format("%d tests passed", passed))
