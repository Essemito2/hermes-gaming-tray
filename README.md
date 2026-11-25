# hermes-gaming-tray

A **KDE Plasma 6 system tray applet** for [Hermes Agent](https://hermes-agent.nousresearch.com)'s
**gaming mode**: it frees the GPU VRAM occupied by your local [llama.cpp](https://github.com/ggml-org/llama.cpp)
model so you can game, and restores the model on demand or at a scheduled auto-off time.

- **Double-click** the tray icon → toggle gaming mode
- **Gaming mode ON** → the model is unloaded from the GPU and locked out of the router: VRAM is *fully* freed (the model cannot be re-loaded by any Hermes session)
- **Gaming mode OFF** → everything is restored; the model loads again on the first chat request, exactly like usual (no auto-load)
- **Auto-off** → the mode switches itself off at a configurable hour (default 05:00), driven by a systemd user timer

## Requirements

- Linux with **KDE Plasma 6**
- **Hermes Agent** with a local llama.cpp model (the `llamacpp` local runtime — see the Hermes docs for local model setup)
- Python 3 (standard library only, nothing to `pip install`)
- systemd user session (only needed for the auto-off timer; the tray works without it)

## Install

```sh
git clone https://github.com/essemito2/hermes-gaming-tray
cd hermes-gaming-tray
./install.sh
```

Then:

```sh
systemctl --user restart plasma-plasmashell
```

Right-click the **notification area** → *Add Widgets* → search **Hermes Gaming Tray**.

With a single staged local model the setup is **zero-config**: the model and the router
port are auto-detected on every call.

## Usage

| Action | Effect |
|---|---|
| double-click the tray icon | toggle gaming mode |
| right-click → *Enable/Disable gaming mode* | same as double-click |
| right-click → *Disable/Enable auto-off* | on/off the scheduled auto-off (persistent) |
| right-click → *Configure…* → **Gaming** tab | set the auto-off hour and toggle auto-off |

The tooltip shows the current state, the session duration and the auto-off countdown.

### CLI

The applet is driven by `~/.local/bin/hermes-gaming`, which you can also use directly:

```sh
~/.local/bin/hermes-gaming on [HOUR]     # enable (auto-off at HOUR:00, default 05:00)
~/.local/bin/hermes-gaming off           # disable
~/.local/bin/hermes-gaming status        # mode / model / router state
~/.local/bin/hermes-gaming verify        # read-only: is the model ready on the live router? (notifies)
~/.local/bin/hermes-gaming offhour       # print the currently effective auto-off hour
~/.local/bin/hermes-gaming set-offhour H # set the persistent auto-off hour (0-23)
~/.local/bin/hermes-gaming set-autooff 0|1  # set the persistent auto-off flag
~/.local/bin/hermes-gaming autooff      # print the effective auto-off flag (1/0)
~/.local/bin/hermes-gaming check        # used by the systemd timer (auto-off at deadline)
```

State and log: `~/.hermes/state/gaming.json`, `~/.hermes/state/gaming-defaults.json`,
`~/.hermes/state/gaming.log`.

## How it works

The Hermes local runtime (`llamacpp`) scans `~/.hermes/models/` for GGUF files when it
spawns the router ("ensure local runtime"); the supervisor sweep (every 30 s) does **not**
re-scan models. `hermes-gaming on` therefore gets away with three things:

1. hide the staged GGUF into `~/.hermes/models/.gaming_hidden/` (the staged model set becomes empty),
2. save and empty the runtime preset,
3. ask the live router to reload (`GET /models?reload=1`) and unload the model from the GPU.

`off` reverses the operation and verifies the model is back in the router's list.
The router port is **dynamic** and re-resolved on every call
(`runtimes/llamacpp/server.json` → `config.yaml` → `18434`, first one that answers),
so port reassignments by Hermes are handled transparently.

Auto-off is a **systemd user timer** (`hermes-gaming-off.timer`) that runs
`hermes-gaming check` every minute; the mode disables itself at the configured hour.

## Limitations

- Plasma 6 / Linux only (the applet cannot exist anywhere else).
- Designed for **one** staged local model: with several staged GGUFs only the first one
  is hidden on `on`.
- The mechanism relies on Hermes internals (local-runtime layout, router API).
  Tested with **Hermes Agent v0.23.4**; if a future Hermes version changes them, run
  `hermes-gaming verify` to diagnose.
- Without a systemd user session the auto-off timer does not run (the tray still works).

## Uninstall

```sh
./install.sh uninstall
```

Removes the script, the systemd units and the applet. State files in `~/.hermes/state/`
are kept.

## License

- `hermes-gaming`, `install.sh`, systemd units, this README: **MIT** (see [LICENSE](LICENSE))
- `plasmoid/` (applet UI): **GPL-3.0-or-later** — derived from
  [Scriptnator](https://store.kde.org/p/2089502/) by tubbadu
  (see [plasmoid/LICENSE](plasmoid/LICENSE))
