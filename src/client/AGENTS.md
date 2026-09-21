# OTCLIENT GAME CLIENT

## OVERVIEW

`src/client/` implements Tibia-specific protocol parsing, game state, map/thing models, player state, and client-facing network behavior on top of the framework.

## WHERE TO LOOK

| Concern | Location |
|---|---|
| Client lifecycle | `client.cpp`, `client.h` |
| Login/game protocol | `protocolgame.cpp`, `protocolgameparse.cpp`, `protocol*` |
| Game state and local player | `game.cpp`, `localplayer.cpp`, `player.cpp` |
| Map and spectators | `map.cpp`, `tile.cpp`, `uimap.cpp` |
| Things/assets | `thing*`, `thingtype*`, `gameconfig*` |
| Client-facing Lua APIs | client bindings and `modules/gamelib/` |

## CONVENTIONS

- Native startup reaches this layer through `g_client.init`; Lua modules then own login/game UI behavior.
- Protocol parsing is version-sensitive. Check the active protocol profile and server/client compatibility before changing packet layouts.
- Deprecated legacy item attributes remain for compatibility; new behavior must follow the current item/appearance path.
- Changes touching downloaded client assets must preserve `data/things/<version>/` and `data/sounds/<version>/` as final runtime paths.

## ANTI-PATTERNS

- Do not infer a protocol behavior from one current profile when the code supports multiple profiles.
- Do not remove legacy parsing without checking the matching Lua/client module consumers.
- Do not treat TODO/FIXME packet branches as harmless cleanup; protocol gaps can change wire compatibility.

## VALIDATION

```text
cmake --preset windows-tests
cmake --build --preset windows-tests
ctest --preset windows-tests
```

The existing native test suite directly covers map spectators, OTML, and encoding helpers, not the full protocol/session surface.
