# Luduvo Full Source — Decompiled

**Luduvo client & studio, fully decompiled from release 49 binaries (Windows, Linux, macOS). Because closed-source sandbox platforms don't get to keep secrets.**

Everything Luduvo ships in its stable channel, reversed:

- `decompiled/` — Ghidra decompilation (pseudo-C) of all six release binaries: `LuduvoGame` (client) and `LuduvoEditor` (studio) for `windows-x86_64`, `linux-x86_64`, and `macos-arm64`.
- `analysis/` — full string tables per binary, plus `SOURCE_TREE_MAP.txt`: the complete 226-file original source tree recovered from assert/log paths (`Platform/spike/...`, `server/...`, `studio/...`, `thirdparty/flecs`, `thirdparty/SDL`).
- `manifests/` — the Ed25519-signed channel manifests (`channels/stable/<platform>.txt`) straight from `assets.luduvo.com`, with sha256-verified bundle URLs.
- `docs/` — full 73-page mirror of `docs.luduvo.com` (engine manual + Luau API reference: 60Hz tick, 30Hz replication, Box3D, sandboxed Luau, matchmaking, content-addressed CDN).
- `mobile/` — mobile compatibility work (see below).

## Engine internals (recovered)

- **Stack**: C++ / Qt6 shell + SDL3 windowing + Vulkan renderer (NVRHI backend) + flecs ECS + embedded **Luau** runtime (Roblox's Lua fork) + OpenAL audio.
- **Client** (`LuduvoGame`): `spike/client/*` (session, camera, input, UI), `spike/graphics/*` (clustered forward renderer, GTAO, OIT, shadows, skybox), `spike/scripting/*` (Luau sandbox: `World.*`, `Store.get/put`, no `os`/`io`/`http`).
- **Studio** (`LuduvoEditor`): `studio/*` (editor main window, panels, publish dialog, rig import, script analysis) — and notably the editor **contains the full game server code** (`server/server_step.cpp`, `server/replication_*.cpp`, `server/chat_gate.cpp`, `server/world.cpp`): local playtest hosts a real server.
- **Protocol**: `luduvo://<token>/<host>/<port>[/<server_pubkey_hex>]`, encrypted `luduvo-auth-v1` handshake, 30Hz replication snapshots/deltas.

## Mobile compatibility

No official Android/iOS builds exist (channel manifests only list win/linux/macos). But the groundwork is already in the engine:

- **SDL3 touch events are fully wired** — `SDL_EVENT_FINGER_DOWN/MOTION/UP`, evdev touchscreen enumeration, gamepad touchpad events, and a Luau-level `() -> ({TouchEvent}, boolean)` binding.
- The Luau sandbox already exposes `Touched`/`TouchEnded` signals on parts.

`mobile/` contains the port scaffolding: Android (Qt6/Android + Gradle) and iOS (Qt6/iOS + Xcode) build configs and CI workflows, ready to drive a rebuild once source reconstruction from the decompilation lands. See `mobile/README.md`.

## Verification

Every bundle was sha256-verified against its Ed25519-signed channel manifest before extraction. Manifest filenames are the sha256 prefixes of their contents (content-addressed CDN).

## Legal

Released for research and interoperability purposes. Luduvo is a trademark of its owner; this repo contains no Luduvo-owned binaries — only decompiled analysis output and public documentation mirrors.
