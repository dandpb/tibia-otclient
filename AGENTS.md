# AGENTS.md

## Client Assets Gate (Mandatory)

Any change touching client-assets auto-installation must preserve the runtime contract below:

1. **Final install paths must remain OTC-standard**
   - `data/things/<version>/`
   - `data/sounds/<version>/`
   - runtime extras in expected runtime locations (for example `bin/*` when distributed upstream)

2. **No alternate permanent source of truth**
   - Do not move runtime loading to `client-assets/` (or any new root) as the primary runtime path.
   - Temporary/cache directories are allowed only as transient staging, never as final runtime source.

3. **Security defaults stay strict unless explicitly justified**
   - `strictManifestSha256 = true`
   - `allowRawFallbackHashMismatch = false`

4. **Cross-platform build safety**
   - Android must not require unsupported `libarchive` linkage.
   - Desktop archive extraction behavior must remain functional.

5. **Verification required in PR description**
   - Explicitly state tested install paths and expected runtime load behavior.

Reference: `docs/client-assets-auto-install.md`

## Repository Map

- Native startup is `src/main.cpp`; `init.lua` is the resource-root sentinel and module bootstrap.
- Reusable framework code is documented at `src/framework/AGENTS.md`.
- Tibia protocol/game code is documented at `src/client/AGENTS.md`.
- Lua/OTUI feature modules are documented at `modules/AGENTS.md`.
- Use CMake presets from this repository; `windows-tests` is the canonical Windows test preset. Preserve the current checkout's user changes in `init.lua`.
