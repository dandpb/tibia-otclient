# OTCLIENT FRAMEWORK

## OVERVIEW

`src/framework/` is the reusable native client runtime: resource discovery, module loading, graphics, UI, OTML, Lua, networking, platform, audio, and dispatching.

## WHERE TO LOOK

| Concern | Location |
|---|---|
| Resource root and files | `core/resourcemanager.cpp`, `core/resourcemanager.h` |
| Module descriptors/lifecycle | `core/modulemanager.cpp`, `core/module.cpp` |
| Main graphical loop | `core/graphicalapplication.cpp` |
| UI widgets/layout | `ui/` |
| OTML parsing | `otml/` |
| Lua bridge | `luaengine/` |
| OS/window/input | `platform/` |
| Socket/protocol primitives | `net/` |

## CONVENTIONS

- `ResourceManager::discoverWorkDir("init.lua")` makes the runtime data root and launch working directory part of the contract.
- `.otmod` dependencies, `@onLoad`, `@onUnload`, and deferred modules are resolved by the framework; feature code should not bypass `ModuleManager`.
- CMake presets are authoritative. `TOGGLE_BIN_FOLDER=ON` moves runtime output under the build tree; otherwise output can land in the source root.
- The `.editorconfig` C++ style is the only tracked formatter contract; there is no repo-wide clang-format gate.

## ANTI-PATTERNS

- Do not call `UIWidget::updateSize` while a flex container is actively laying out.
- Do not destroy Android surfaces during low-memory recovery.
- Do not treat the built-in encryption path as a secure transport without an explicit threat review.
- Do not add permanent client-asset roots; preserve the parent asset gate and strict hashes.

## VALIDATION

```text
cmake --preset windows-tests
cmake --build --preset windows-tests
ctest --preset windows-tests
```

The native tests cover OTML, UTF encoding, and map spectator behavior; most graphics/platform/network code is not directly covered.
