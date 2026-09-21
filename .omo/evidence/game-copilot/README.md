# Game Copilot validation evidence

Final runtime date: 2026-08-18.

## Automated gates

- UI, OTMOD, and bootstrap contract checks passed.
- Lua behavior suites passed: 9 + 5 = 14 scenarios.
- Lua 5.1 parser passed for 14 runtime and test files.
- Every changed Lua, OTUI, and MJS file is at or below 250 useful lines.
- `git diff --check` passed.
- The final OTClient log scan found no module, Lua, error, or fatal entry.
- Two independent visual reviewers returned `PASS` for the final movement, emergency, route-learning, and autonomous-replay evidence set (`12`-`16`, `19`, and `20`).

## Runtime evidence

- `07-final-panel.jpg`: final multi-script module loaded, character online, full panel and compact session log visible.
- `08-final-confirm-pending.jpg`: confirm mode held `walk north` at position `32369, 32190, 7`.
- `09-final-confirmed-movement.jpg`: after confirmation, pending action cleared and position changed to `32369, 32189, 7`.
- `10-final-emergency-pause.jpg`: a second pending walk was cancelled; mode became paused and position stayed `32369, 32189, 7`.
- `12-clean-confirm-pending.jpg` and `13-clean-confirmed-movement.jpg`: tooltip-free final movement evidence; Y changed from `32189` to `32188` and the activity line changed from planned to dispatched.
- `14-clean-emergency-explicit.jpg`: tooltip-free emergency evidence; mode is paused, pending is none, position stayed `32369, 32188, 7`, and the panel states `Emergency: walk cancelled`.
- `15-clean-route-recording.jpg`, `16-clean-route-learned.jpg`, and `17-clean-autonomous-replay.jpg`: tooltip-free final route evidence; the route grows to two points, is persisted, and autonomous replay moves Y from `32188` to `32187`.
- `18-final-safe-handoff.jpg`: final live state left in guide mode with no pending action.
- `19-autonomous-replay-start.jpg` and `20-autonomous-replay-finish.jpg`: exact tooltip-free replay pair in autonomous mode; Y changes from `32188` to `32187` with no pending action.
- `21-final-guide-handoff.jpg`: final reconnection state; Knight 1 is online in guide mode at `32369, 32187, 7`, with no pending action and the learned two-point route loaded.
- `03-route-recording.jpg`, `04-route-learned.jpg`, and `05-autonomous-replay.jpg`: route recording, persisted learning, and autonomous replay states.

Persisted state contained 18 commands, 200 bounded events, 43 observations, a learned two-point `last_route`, a dispatched final walk, and a final walk rejected as `cancelled by emergency`.
