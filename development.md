# SceneBuilder — Development

SceneBuilder is part of the DREAM mod family (Build 42):
- DREAM-Workspace (multi-repo convenience): https://github.com/christophstrasen/DREAM-Workspace

## Quickstart (single repo)

Prereqs: `rsync`, `inotifywait` (`inotify-tools`), `inkscape`.

Watch + deploy (default: Workshop wrapper under `~/Zomboid/Workshop`):

```bash
./dev/watch.sh
```

Optional: deploy to `~/Zomboid/mods` instead:

```bash
TARGET=mods ./dev/watch.sh
```

## Notes

- This repo already shipped to Workshop; `Contents/mods/SceneBuilder/42/mod.info` is considered published surface.
- The mod payload is under `Contents/mods/SceneBuilder/`.

## Tests (headless)

SceneBuilder unit tests run outside the Project Zomboid engine:

```bash
busted tests/unit
```

Lint:

```bash
luacheck Contents/mods/SceneBuilder/42/media/lua/shared/SceneBuilder Contents/mods/SceneBuilder/42/media/lua/shared/SceneBuilder.lua
```
