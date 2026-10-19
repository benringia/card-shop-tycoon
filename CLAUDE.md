# Card Shop Tycoon (Roblox)

Read DESIGN.md first. It is the source of truth for scope, numbers, and structure.

## Stack
- Roblox, Luau, synced with Rojo (`default.project.json`)
- `src/server` → ServerScriptService.Server, `src/client` → StarterPlayerScripts.Client, `src/shared` → ReplicatedStorage.Shared
- Files use `.luau`. `init.server.luau` / `init.client.luau` are entry points.

## Rules
- Server authoritative. Client sends intents through remotes, server validates and changes state.
- All cash/XP changes go through EconomyService only.
- Pack rolls happen on the server only.
- Validate and rate-limit every remote.
- All tunable numbers live in `src/shared/Config`. No magic numbers in services.
- Use `--!strict` and type annotations where practical.
- Mobile-first UI.
- Never edit synced scripts inside Studio; code lives in this repo.

## Workflow
- Work through the MVP checklist in DESIGN.md section 11, one system at a time.
- After each system, tell me exactly what to test in Studio.
