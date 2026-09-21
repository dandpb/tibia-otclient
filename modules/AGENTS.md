# OTCLIENT MODULES

## OVERVIEW

`modules/` is the scripted UI and gameplay layer. Each module is described by `.otmod` metadata and typically combines Lua behavior with OTUI layouts and assets.

## STRUCTURE

```text
modules/
├── client_*       # startup, login, options, top menu, localization
├── game_*         # in-game UI, containers, battle, market, chat, HUD
├── corelib/       # shared Lua/UI helpers
├── gamelib/       # protocol constants and game-facing Lua APIs
└── modulelib/     # Controller/EventController lifecycle helpers
```

## WHERE TO LOOK

- Bootstrap and module order: root `init.lua`, `client/client.lua`, and `.otmod` descriptors.
- Login/character list: `client_entergame/`.
- Gameplay viewport and UI: `game_interface/`, `game_containers/`, `game_console/`, `game_inventory/`.
- Protocol/extended opcodes: `gamelib/protocolgame.lua` and the matching native parser.
- Lifecycle-safe event/opcode registration: `modulelib/controller.lua`.

## CONVENTIONS

- Declare dependencies in `.otmod`; keep `@onLoad`/`@onUnload` balanced and unregister callbacks on unload.
- OTUI uses exactly two spaces per nesting level; preserve existing style and widget anchor conventions.
- Lua CI compiles scripts for syntax only; behavioral coverage is narrow, so manually trace lifecycle and protocol paths.

## ANTI-PATTERNS

- Do not cache mutable module API functions when the module documents that they may be replaced.
- Do not leave extended-opcode handlers registered after module unload.
- Do not use the legacy `mods/game_bot/functions/ui_legacy.lua` path; it is explicitly marked as forbidden.
- Do not move permanent runtime assets out of the standard `data/` locations.

## VALIDATION

```text
cmake --preset windows-tests
cmake --build --preset windows-tests
ctest --preset windows-tests
```

For Lua-only changes, run the repository CI-equivalent syntax compilation over `data/`, `modules/`, and `mods/` with LuaJIT.
