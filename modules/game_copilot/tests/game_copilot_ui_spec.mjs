import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const content = readFileSync("modules/game_copilot/game_copilot.otui", "utf8");
const otmodContent = readFileSync("modules/game_copilot/game_copilot.otmod", "utf8");
const bootstrapContent = readFileSync("init.lua", "utf8");
const luaFiles = [
  "game_copilot.lua",
  "game_copilot_runtime.lua",
  "game_copilot_lifecycle.lua",
  "game_copilot_controls.lua",
  "game_copilot_commands.lua",
  "game_copilot_routes.lua",
  "game_copilot_actions.lua",
  "game_copilot_quests.lua",
  "game_copilot_learning.lua",
  "game_copilot_persistence.lua",
  "game_copilot_ui.lua",
];
const luaContent = luaFiles
  .map((luaFile) => readFileSync(`modules/game_copilot/${luaFile}`, "utf8"))
  .join("\n");

assert.doesNotMatch(content, /combat execution is not implemented/i, "combat tooltip is stale");
assert.doesNotMatch(content, /loot execution is not implemented/i, "loot tooltip is stale");
assert.doesNotMatch(content, /NPC talk execution is not implemented/i, "NPC tooltip is stale");
assert.doesNotMatch(content, /mana is stored only/i, "mana tooltip is stale");
assert.match(content, /Confirm pending action/, "confirmation must cover all supported actions");
assert.match(content, /ScrollablePanel/, "the panel must remain usable when its content exceeds the viewport");
assert.match(content, /vertical-scrollbar: gameCopilotScroll/, "the panel must expose a vertical scroll affordance");
assert.match(content, /VerticalScrollBar/, "the panel must render its scroll control");
assert.doesNotMatch(content, /@onTextChange/, "dynamic quest counts must not run during OTUI construction");
for (const direction of ["north", "east", "south", "west"]) {
  assert.match(content, new RegExp(`requestWalk\\("${direction}"\\)`), `missing ${direction} walk control`);
}
for (const action of ["Combat", "Loot", "NpcTalk"]) {
  assert.match(luaContent, new RegExp(`request${action}`), `missing ${action} action API`);
}
assert.match(luaContent, /addMenuHook/, "explicit target actions must be reachable from the game context menu");
assert.match(luaContent, /removeMenuHook/, "context menu hooks must be removed on module unload");
assert.doesNotMatch(content, /@onClick: gameCopilot:setPermission/, "permission checkboxes must publish their post-toggle state");
assert.equal((content.match(/@onCheckChange: gameCopilot:setPermission/g) || []).length, 4,
  "all four permission checkboxes must use onCheckChange");
for (const control of ["startRouteRecording", "stopRouteRecording", "startRoutePlayback"]) {
  assert.match(content, new RegExp(control), `missing ${control} route control`);
}
assert.match(content, /gameCopilot:refreshQuestLog\(\)/, "server quest log must be refreshable from the panel");
assert.doesNotMatch(content, /text: Refresh counts/, "local counters must update automatically without a redundant control");
assert.doesNotMatch(content, /text: Save local state/, "automatic persistence must not consume unreachable panel space");
assert.match(luaContent, /sessionLog:setText/, "session counters must update automatically from Lua");
assert.match(luaContent, /recursiveGetChildById/, "nested scroll content must retain live control lookups");
assert.match(luaContent, /cancelled by emergency[\s\S]*Emergency: walk cancelled/,
  "emergency cancellation must be visible in the panel activity line");
assert.doesNotMatch(content, /id: activeQuests/, "quest counts must use one compact summary line");
assert.doesNotMatch(content, /id: completedQuests/, "quest counts must use one compact summary line");
assert.match(luaContent, /Quests: %d \(%d active \/ %d done\)/,
  "quest summary must retain active and completed counts");

assert.match(otmodContent, /name: game_copilot/, "OTMOD name must match the Lua module");
assert.match(otmodContent, /sandboxed: true/, "Copilot must remain sandboxed");
assert.match(otmodContent, /autoload: true/, "Copilot must autoload");
assert.match(otmodContent, /dependencies: \[ game_interface, game_mainpanel, game_walk \]/,
  "OTMOD dependencies must load the required game surfaces");
assert.match(otmodContent, /scripts: \[[^\]\r\n]+\]/,
  "OTMOD script lists must stay on one parser-compatible line");
for (const luaFile of luaFiles) {
  assert.match(otmodContent, new RegExp(luaFile.replace(".", "\\.")), `OTMOD must load ${luaFile}`);
  const source = readFileSync(`modules/game_copilot/${luaFile}`, "utf8");
  const pureLines = source.split(/\r?\n/).filter((line) => line.trim() && !line.trim().startsWith("--"));
  assert.ok(pureLines.length <= 250, `${luaFile} exceeds the 250-line responsibility boundary`);
}
const uiPureLines = content.split(/\r?\n/).filter((line) => line.trim() && !line.trim().startsWith("#"));
assert.ok(uiPureLines.length <= 250, "game_copilot.otui exceeds the 250-line responsibility boundary");
for (const testLuaFile of [
  "game_copilot_test_fixture.lua",
  "game_copilot_spec.lua",
  "game_copilot_persistence_spec.lua",
]) {
  const source = readFileSync(`modules/game_copilot/tests/${testLuaFile}`, "utf8");
  const pureLines = source.split(/\r?\n/).filter((line) => line.trim() && !line.trim().startsWith("--"));
  assert.ok(pureLines.length <= 250, `${testLuaFile} exceeds the 250-line responsibility boundary`);
}
assert.match(otmodContent, /@onLoad: gameCopilot\.init\(\)/, "OTMOD must initialize the module");
assert.match(otmodContent, /@onUnload: gameCopilot\.terminate\(\)/, "OTMOD must terminate the module");
assert.match(bootstrapContent, /addSearchPath\(g_resources\.getWorkDir\(\) \.\. 'modules'/,
  "bootstrap must expose the modules search path");
assert.match(bootstrapContent, /autoLoadModules\(999\)/, "bootstrap must load game modules");

assert.match(luaContent, /createProfile\("Knight Noob 1"\)/, "default profile must be Knight Noob 1");
assert.match(luaContent, /guide = true[\s\S]*confirm = true[\s\S]*autonomous = true/,
  "all three execution modes must remain valid");
assert.match(luaContent, /allowWalking[\s\S]*allowCombat[\s\S]*allowLoot[\s\S]*allowNpcTalk/,
  "all four action gates must remain mapped");

console.log("UI/OTMOD/bootstrap contract checks passed");
