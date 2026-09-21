dofile("modules/game_copilot/tests/game_copilot_test_fixture.lua")

test("all four permission gates reject their matching action", function()
  local gates = {
    { permission = "allowWalking", action = { type = "walk", direction = "north" } },
    { permission = "allowCombat", action = { type = "combat" } },
    { permission = "allowLoot", action = { type = "loot" } },
    { permission = "allowNpcTalk", action = { type = "npc_talk" } }
  }
  for _, gate in ipairs(gates) do
    resetCopilot()
    gameCopilot.profile[gate.permission] = false
    local allowed, reason = gameCopilot:canExecuteAction(gate.action, true)
    expect(allowed == false, gate.permission .. " allowed its action")
    expect(reason == gate.action.type .. " is disabled in the profile", "wrong rejection for " .. gate.permission)
  end
end)

test("each executable action reaches its local API with an unverified outcome", function()
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
  local actions = {
    { name = "walk", request = function() return gameCopilot:requestWalk("north") end, calls = function() return walkCalls end },
    { name = "combat", request = function() return gameCopilot:requestCombat(monster) end, calls = function() return attackCalls end },
    { name = "loot quick", request = function() return gameCopilot:requestLoot(corpse, "quick_loot") end, calls = function() return lootCalls end },
    { name = "loot open", request = function() return gameCopilot:requestLoot(corpse, "open_corpse") end, calls = function() return corpseOpenCalls end },
    { name = "NPC talk", request = function() return gameCopilot:requestNpcTalk(npc, "hi") end, calls = function() return talkCalls end }
  }
  for _, entry in ipairs(actions) do
    resetCopilot()
    gameCopilot.mode = "autonomous"
    local dispatched, reason = entry.request()
    expect(dispatched == true, entry.name .. " was not dispatched: " .. tostring(reason))
    expect(reason == "client command dispatched; outcome unverified", entry.name .. " did not expose the outcome boundary")
    expect(entry.calls() == 1, entry.name .. " did not call its local API exactly once")
    expect(gameCopilot.session.commands[1].status == "dispatched", entry.name .. " command was not marked dispatched")
  end
end)

test("quest observation keeps server data separate and requests both native views", function()
  resetCopilot()
  gameCopilot.session.quests.local_note = { id = "local_note", title = "Local note" }
  expect(gameCopilot:refreshQuestLog() == true, "quest log refresh was not requested")
  gameCopilot:onQuestLog({ { 42, "The First Quest", true }, { 43, "", false } })
  gameCopilot:onQuestLine(42, { { "Find the key", "Search the crypt", 7 } })
  expect(questLogCalls == 1, "quest log API was not called once")
  expect(gameCopilot.session.quests.local_note ~= nil, "server observation replaced local notes")
  expect(gameCopilot.session.serverQuestState["42"].completed == true, "server quest completion was not observed")
  expect(#gameCopilot.session.serverQuestState["42"].missions == 1, "quest line mission was not parsed")
  expect(gameCopilot.session.serverQuestState["43"] == nil, "malformed quest was not rejected")
end)

test("profile and session persistence round-trip through the resource boundary", function()
  resetCopilot()
  gameCopilot.profile.character = "Knight Noob 1"
  gameCopilot.profile.allowWalking = true
  expect(gameCopilot:setQuest("quest-1", { title = "First quest", state = "active" }) == true, "quest was not stored")
  expect(gameCopilot:learnObservation("door", { text = "Use the east door" }) == true, "observation was not stored")
  expect(gameCopilot:save() == true, "profile and session were not saved")
  expect(persistedFiles[gameCopilot:profilePath()] == "PROFILE", "profile path was not written")
  expect(persistedFiles[gameCopilot:sessionPath()] == "SESSION", "session path was not written")

  persistedProfile = {
    character = "Knight Noob 1", allowWalking = true, allowCombat = false,
    allowLoot = false, allowNpcTalk = false, minimumHealthPercent = 70, minimumManaPercent = 30
  }
  persistedSession = {
    quests = { ["quest-2"] = { title = "Loaded quest", state = "active", progress = 25 } },
    events = { { type = "loaded" } }, commands = {},
    knowledge = { routes = {}, observations = { note = { text = "Loaded note" } } }
  }
  gameCopilot.profile = { character = "Knight Noob 1", allowWalking = false, allowCombat = true, allowLoot = true, allowNpcTalk = true, minimumHealthPercent = 60, minimumManaPercent = 20 }
  gameCopilot.session = { quests = {}, events = {}, commands = {}, knowledge = { routes = {}, observations = {} }, observations = 0 }
  gameCopilot:loadProfile()
  gameCopilot:loadSession()
  expect(gameCopilot.profile.allowWalking == true and gameCopilot.profile.minimumHealthPercent == 70, "profile did not round-trip")
  expect(gameCopilot.session.quests["quest-2"].progress == 25, "quest session did not round-trip")
  expect(gameCopilot.session.knowledge.observations.note.text == "Loaded note", "knowledge did not round-trip")
end)

test("login isolates profile and session state between characters", function()
  resetCopilot()
  persistedFiles = {}
  gameCopilot.session.quests.from_character_a = { id = "from_character_a", title = "A" }
  g_game.getCharacterName = function() return "Character B" end
  gameCopilot:onGameStart()
  expect(gameCopilot.profile.character == "Character B", "new character profile was not selected")
  expect(gameCopilot.session.quests.from_character_a == nil, "quest state leaked between characters")
  expect(gameCopilot.session.observations == 1, "new character session did not start fresh")
end)

print(string.format("%d tests passed", passed))
