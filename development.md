# SceneBuilder — Development

SceneBuilder is part of the DREAM mod family (Build 42):
- DREAM-Workspace (multi-repo convenience): https://github.com/christophstrasen/DREAM-Workspace

Prereqs (for the `dev/` scripts): `rsync`, `inotifywait` (`inotify-tools`), `inkscape`.

## Sync

Deploy to your local Workshop wrapper folder (default):

```bash
./dev/sync-workshop.sh
```

Optional: deploy to `~/Zomboid/mods` instead:

```bash
./dev/sync-mods.sh
```

## Watch

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

## Tests

SceneBuilder unit tests run outside the Project Zomboid engine:

```bash
busted --helper=tests/helper.lua tests/unit
```

Note: tests assume DREAMBase is available at `../DREAMBase` (DREAM-Workspace layout) or `external/DREAMBase`.

## Lint

```bash
luacheck Contents/mods/SceneBuilder/42/media/lua/shared/SceneBuilder Contents/mods/SceneBuilder/42/media/lua/shared/SceneBuilder.lua
```

## Pre-commit hooks

This repo ships a `.pre-commit-config.yaml` mirroring CI (`luacheck` + `busted`).

Enable hooks:

```bash
pre-commit install
```

Run on demand:

```bash
pre-commit run --all-files
```
