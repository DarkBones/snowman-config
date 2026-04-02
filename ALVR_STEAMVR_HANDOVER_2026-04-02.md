# ALVR / SteamVR / Quest 3 Handover

Date: 2026-04-02
Repo: `/home/bas/snowman-config`
Host: `dorkbones`
User: `bas`
Context: multi-day debugging session to get ALVR + SteamVR + Quest 3 working on NixOS/Linux, with special focus on SteamVR compositor behavior, ALVR wrapper behavior, NVENC failure, controller input, dashboard rendering, and Hitman 3 VR startup.

This handover is meant to be detailed enough that work can resume later without reconstructing the whole investigation.

## Current Status

At the moment of handoff:

- Basic ALVR streaming is working.
- The Quest can now display SteamVR content.
- Software encoding is forced, because hardware/NVENC encoding was failing.
- Controller input was re-enabled and worked well enough to launch Hitman 3.
- SteamVR no longer fails at the very earliest startup stages.
- The most recent unresolved problem is during Hitman 3 VR mode handoff / restart:
  - Hitman launches.
  - The user can see the game/menu in the Quest.
  - When Hitman asks to enable VR and the user accepts, the transition still fails.
  - The most recent visible user-facing error was an assertion popup:

    `Assertion failed!`

    `File: ../src-vrclient/vrcompositor_manual.c`

    `Line: 1679`

    `Expression: !status`

- The last patch I made was intended to prevent SteamVR Home / dashboard takeover during that transition.
- The user has **not yet run** that latest patch. That is the immediate next thing to do when work resumes.

## Immediate Next Step When Resuming

The very next thing to do is:

1. Run `snowman dev`
2. Fully quit Steam
3. Start `alvr-dashboard-x11`
4. Start SteamVR
5. Launch Hitman 3 and accept VR mode again

Then collect:

```bash
sed -n '40,70p' ~/.local/share/Steam/config/steamvr.vrsettings
rg -n "Starting SteamVR Home launch because|openvr.tool.steamvr_environments|showOnAppExit" ~/.local/share/Steam/logs/vrserver.txt
```

Reason:

- The newest untested patch sets:
  - `steamvr.enableHomeApp = false`
  - `dashboard.showOnAppExit = false`
- We need to verify whether SteamVR still launches `openvr.tool.steamvr_environments` after Hitman exits to relaunch into VR.

This is the exact point where work paused.

## Working Theory Right Now

The current working theory is:

- Hitman 3 exits and relaunches itself during VR enablement.
- During that transition, SteamVR may be reclaiming scene ownership by starting SteamVR Home / dashboard.
- That can interfere with the compositor handoff and leave Hitman in a bad VR compositor state.
- The assertion popup in `vrcompositor_manual.c` suggests the game-side compositor client path is seeing a bad or unexpected compositor status during that transition.

This is not the same as the earlier startup failures. We moved significantly beyond those.

## What Is Known To Work

These are meaningful milestones already achieved:

- ALVR server starts.
- SteamVR starts.
- Quest receives video stream.
- SteamVR dashboard / library has been visible in-headset in some runs.
- Controller input worked well enough to launch Hitman 3.
- Hitman 3 reaches the prompt asking whether to enable VR mode.
- In at least one run, the game menu / image was visible in the Quest before the later transition failure.

This means:

- Networking / headset link are not the primary blockers anymore.
- The old ALVR wrapper panic has been solved.
- The old NVENC failure has been bypassed.
- The main remaining problem is the VR application transition and compositor ownership / presentation path.

## Important Files Changed In Repo

### 1. `pkgs/alvr-20.13.0.nix`

Local ALVR package override.

Purpose:

- Patch ALVR’s `vrcompositor_wrapper` behavior.

Background:

- Earlier, ALVR’s `vrcompositor-wrapper` panicked when invoked in a way that made `readlink(argv0)` fail with `EINVAL`.
- This happened because the wrapper assumed it was always entered via a symlink.

Current patch behavior:

- `read_link(argv0)` now falls back to `argv0` itself if `readlink` fails.
- This removed the fatal panic:

  `Failed to read vrcompositor symlink: Invalid argument (os error 22)`

### 2. `modules/alvr.nix`

Now uses the local ALVR package:

- `pkgs.callPackage ../pkgs/alvr-20.13.0.nix { }`

### 3. `home/roles/gaming.nix`

This is the main file carrying almost all of the live fixes.

Key current responsibilities in this file:

- Provide `alvr-dashboard-x11`
- Force ALVR session settings to a known-working baseline
- Force SteamVR launch options to avoid Wayland compositor weirdness
- Patch `vrwebhelper.sh` for `nix-ld` library lookup
- Clear SteamVR safe mode blocks for ALVR
- Write SteamVR settings relevant to mirror view and Home/dashboard behavior

## Current Important Behavior In `home/roles/gaming.nix`

### `alvr-dashboard-x11`

This wrapper:

- unsets:
  - `WAYLAND_DISPLAY`
  - `WAYLAND_SOCKET`
  - `SWAYSOCK`
  - `HYPRLAND_INSTANCE_SIGNATURE`
- sets:
  - `XDG_SESSION_TYPE=x11`

Purpose:

- Avoid running the dashboard and SteamVR path through a Wayland-flavored environment when debugging compositor problems.

### `ensureAlvrSessionWritable`

This activation block ensures `~/.config/alvr/session.json` is writable and forces a set of fields.

Important currently forced values:

- `.openvr_config.use_separate_hand_trackers = false`
- `.openvr_config.force_sw_encoding = true`
- `.session_settings.headset.controllers.enabled = true`
- `.session_settings.headset.controllers.content.tracked = true`
- `.session_settings.headset.controllers.content.hand_skeleton.enabled = true`
- `.session_settings.video.encoder_config.software.force_software_encoding = true`
- `.session_settings.video.encoder_config.software.thread_count = 0`

Why:

- Software encoding was required to bypass the CUDA/NVENC failure.
- Controllers and hand skeleton were re-enabled after earlier debugging had disabled input.

### `ensureSteamVrLaunchOptions`

This activation block modifies SteamVR launch options and SteamVR settings.

Current launch options string sets or unsets:

- unsets:
  - `WAYLAND_DISPLAY`
  - `WAYLAND_SOCKET`
  - `SWAYSOCK`
  - `HYPRLAND_INSTANCE_SIGNATURE`
- sets:
  - `DISPLAY=$DISPLAY`
  - `XAUTHORITY=${XAUTHORITY:-$HOME/.Xauthority}`
  - `XDG_SESSION_TYPE=x11`
  - `SDL_VIDEODRIVER=x11`
  - `GDK_BACKEND=x11`
  - `__NV_PRIME_RENDER_OFFLOAD=1`
  - `__VK_LAYER_NV_optimus=NVIDIA_only`
  - `__GLX_VENDOR_LIBRARY_NAME=nvidia`
  - `VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json`
  - `QT_QPA_PLATFORM=xcb`
- launches:
  - `$steamvr_root/bin/vrmonitor.sh %command%`

Purpose:

- Keep SteamVR on an X11 path.
- Avoid Wayland / DRM-lease behavior during normal SteamVR startup.
- Force NVIDIA Vulkan ICD selection explicitly.

### `vrwebhelper.sh` patch

The activation script prepends:

- `/run/current-system/sw/share/nix-ld/lib`

to `LD_LIBRARY_PATH` inside SteamVR’s `vrwebhelper.sh`.

Purpose:

- Avoid missing-library issues in SteamVR webhelper subprocesses under NixOS.

### SteamVR settings currently written by activation

The activation script currently writes these values into `~/.local/share/Steam/config/steamvr.vrsettings`:

- `driver_alvr_server.blocked_by_safe_mode = false`
- `driver_prism.blocked_by_safe_mode = false` if `driver_prism` exists
- `steamvr.showMirrorView = false`
- `steamvr.mirrorViewDisplayMode = 0`
- `steamvr.mirrorViewEye = 0`
- `steamvr.enableHomeApp = false`
- `dashboard.showOnAppExit = false`

The last one, `dashboard.showOnAppExit = false`, is the newest patch and has **not been tested yet**.

## Build Status

Recent changes were consistently building.

Both of these succeeded repeatedly:

- `nix build .#homeConfigurations.bas@dorkbones.activationPackage`
- `nix build .#nixosConfigurations.dorkbones.config.system.build.toplevel --impure`

The user applied changes using:

- `snowman dev`

## Chronological Problem History

### Phase 1: SteamVR / ALVR startup failures

Initial issues included:

- ALVR / SteamVR failing very early
- `vrcompositor` wrapper and SteamVR compositor path breaking in multiple ways
- `GLIBC_PRIVATE` crashes in SteamVR compositor path
- wrapper panics

Notable failures seen:

- `symbol lookup error: /lib/libc.so.6: undefined symbol: __nptl_change_stack_perm, version GLIBC_PRIVATE`
- ALVR wrapper panic:
  - `Failed to read vrcompositor symlink: Invalid argument (os error 22)`

These were addressed by:

- patching the ALVR wrapper in `pkgs/alvr-20.13.0.nix`
- later having the user verify SteamVR file integrity

### Phase 2: SteamVR live install got into a poisoned compositor state

At one stage, we were experimenting with activation logic that replaced or wrapped:

- `vrcompositor`
- `vrcompositor.real`
- `vrcompositor-launcher.sh`

This turned out to be dangerous because SteamVR’s live install ended up in a broken chain where:

- `vrcompositor` no longer pointed cleanly at the expected binary/launcher path
- SteamVR could enter loops or wrapper recursion

This was eventually corrected by:

- removing those activation hacks from the repo
- restoring SteamVR to a cleaner baseline
- asking the user to verify SteamVR files through Steam

### Phase 3: SteamVR file verification

The user verified SteamVR’s integrity through Steam.

Result:

- Steam reported two corrupted files and redownloaded them.
- This was important. It fixed some of the poisoned live install state.

### Phase 4: ALVR video path finally works, but NVENC/CUDA fails

Once startup improved, ALVR produced a new error:

- `error in encoder thread: Failed to transfer Vulkan image to CUDA frame Generic error in an external library`
- also:
  - `CUDA_ERROR_INVALID_VALUE: invalid argument`

This was bypassed by forcing software encoding in `session.json`.

That was a major breakthrough.

### Phase 5: Quest starts showing SteamVR content

After forcing software encoding:

- The Quest could see the Steam library.
- Streaming worked.

At that point there were still issues:

- invisible dashboard / panels in some runs
- controller/input issues in some runs

### Phase 6: Controller input was missing

At some point the Quest showed Steam content but input did not work.

Root cause:

- input-related settings had been disabled earlier during debugging

Fix:

- controllers enabled again in ALVR session config
- controller tracking enabled
- hand skeleton enabled

This allowed interaction again and was good enough to launch Hitman 3.

### Phase 7: SteamVR dashboard / library panel visibility and mirror-window issues

SteamVR then showed problems like:

- dashboard/library visible sometimes
- dashboard/library invisible or transparent sometimes
- virtual keyboard invisible
- compositor log showing:
  - `Found bad mirror window settings:`
  - `CHmdWindowSDL: Failed to initialize mirror window`
  - `Failed to start compositor: VRInitError_Compositor_CannotConnectToDisplayServer`

We tried to reduce these issues by:

- forcing SteamVR to X11
- explicitly setting mirror-related config values
- disabling the mirror view

This improved some behavior, but did not fully solve the later Hitman transition failure.

### Phase 8: Hitman 3 becomes launchable, but VR transition fails

At a later stage, the user could:

- launch Hitman 3
- see the VR mode prompt
- see the game/menu in the Quest

But on enabling VR mode:

- either the screen went black/gray
- or SteamVR restarted/crashed
- or a new assertion popup appeared

This is the main current problem.

## Important Logs And Their Meaning

### 1. ALVR wrapper panic is fixed

Old failure:

- `Failed to read vrcompositor symlink: Invalid argument (os error 22)`

This is no longer the primary issue after the package patch.

### 2. NVENC/CUDA failure was bypassed

Old failure:

- `Failed to transfer Vulkan image to CUDA frame`
- `CUDA_ERROR_INVALID_VALUE: invalid argument`

This is why software encoding is forced.

### 3. SteamVR mirror-window / display-server failures

Important historical log lines:

- `Found bad mirror window settings:`
- `CHmdWindowSDL: Failed to initialize mirror window`
- `Failed to start compositor: VRInitError_Compositor_CannotConnectToDisplayServer`

This led to:

- forcing X11 env vars
- disabling mirror view in `steamvr.vrsettings`

### 4. Recurring compositor assertion

A recurring SteamVR-side compositor assertion appears in logs:

- `ASSERT: "Unhandled sampler filter type!" at /data/src/common/vrcommon/vrrenderer/vulkanrenderer.cpp:2291.`

This appears multiple times.

It may be significant:

- It suggests SteamVR’s Vulkan renderer path is encountering something unexpected in the ALVR display / compositor path.
- It may or may not be directly fatal each time.

### 5. WaitForPresent watchdog failure

Also seen:

- `Failed Watchdog timeout in thread Render in WaitForPresent after 5.423972 seconds. Aborting.`

This indicates the compositor can get stuck waiting for presentation during certain transitions.

### 6. SteamVR Home launching on Hitman exit

Very important current clue in `vrserver.txt`:

On recent runs, after Hitman exits to restart into VR:

- `Starting SteamVR Home launch because steam.app.1659040 exited after ...`
- `Attempting to start home app openvr.tool.steamvr_environments`
- then `steamtours` is launched

This is exactly why the last two settings were added:

- `steamvr.enableHomeApp = false`
- `dashboard.showOnAppExit = false`

At the moment of handoff:

- `enableHomeApp = false` was present in the settings file
- but SteamVR still launched Home
- so `dashboard.showOnAppExit = false` was added
- that latest patch has **not yet been tested**

### 7. Latest user-visible error

The latest popup shown by the user:

- `Assertion failed!`
- `File: ../src-vrclient/vrcompositor_manual.c`
- `Line: 1679`
- `Expression: !status`

User description:

- Hitman started
- menu was visible in Quest
- user selected `Enable VR`
- got that assertion
- Hitman screen froze
- virtual controllers did **not** freeze this time

That is meaningful progress compared to earlier harder failures.

## Exact Current Live SteamVR Settings Snapshot

At one recent point, `~/.local/share/Steam/config/steamvr.vrsettings` contained:

```json
{
  "DesktopUI": {
    "pairing": "1520,780,799,599,0",
    "settings_desktop": "1520,780,799,599,0"
  },
  "driver_alvr_server": {
    "blocked_by_safe_mode": false
  },
  "driver_prism": {
    "blocked_by_safe_mode": false
  },
  "steamvr": {
    "directModeDisabled": true,
    "disableAsync": true,
    "mirrorViewDisplayMode": 0,
    "mirrorViewEye": 0,
    "showMirrorView": false,
    "enableHomeApp": false
  },
  "dashboard": {
    "lastAccessedExternalOverlayKey": "valve.steam.desktopgame.1659040"
  }
}
```

The next run should also include:

- `dashboard.showOnAppExit = false`

after the user applies the newest patch via `snowman dev`.

## Commands That Were Commonly Used

Useful for continuing:

### Rebuild/apply

```bash
snowman dev
```

### Launch ALVR in X11-flavored mode

```bash
alvr-dashboard-x11
```

### Inspect SteamVR settings

```bash
sed -n '1,120p' ~/.local/share/Steam/config/steamvr.vrsettings
```

### Check for Home/dashboard relaunch interference

```bash
rg -n "Starting SteamVR Home launch because|openvr.tool.steamvr_environments|showOnAppExit" ~/.local/share/Steam/logs/vrserver.txt
```

### Check compositor tail

```bash
tail -n 40 ~/.local/share/Steam/logs/vrcompositor.txt
```

### Check monitor tail

```bash
tail -n 40 ~/.local/share/Steam/logs/vrmonitor.txt
```

### Check server tail

```bash
tail -n 80 ~/.local/share/Steam/logs/vrserver.txt
```

## Things That Should Not Be Reintroduced

Do not reintroduce the old activation hacks that mutate live SteamVR compositor files in risky ways, especially:

- replacing `vrcompositor` with ad-hoc shell scripts
- creating fake `vrcompositor.real`
- wrapper chains around `vrcompositor-launcher.sh`

That path caused:

- broken recursion
- stale wrapper chains
- confusing mixed states in SteamVR’s live install

The SteamVR install had to be repaired via Steam verification after those experiments.

## Open Questions / Likely Next Investigation Paths

If the latest `showOnAppExit = false` patch does **not** stop the failure, likely next directions are:

### 1. Confirm whether SteamVR Home still launches

This is the first check because it directly tests the last hypothesis.

If Home no longer launches but the assertion remains, then the failure is deeper in the Hitman VR transition itself.

### 2. Investigate SteamVR Vulkan renderer assertion

This recurring line remains suspicious:

- `ASSERT: "Unhandled sampler filter type!" at ... vulkanrenderer.cpp:2291`

Possible future direction:

- look for a SteamVR setting that changes compositor renderer behavior
- look for texture filtering / mirror / dashboard settings that map to that assertion

### 3. Investigate whether the app transition leaves stale scene ownership or overlay state

The manual compositor assertion in `vrcompositor_manual.c` suggests the app’s OpenVR client is getting an unexpected compositor state.

Possible angles:

- dashboard or overlay visibility during relaunch
- Steam overlay / desktop game overlay behavior during the transition
- Proton/game relaunch timing versus SteamVR scene app ownership

### 4. Capture more game-side logs if needed

We previously found:

- `/home/bas/.local/share/Steam/steamapps/compatdata/1659040/pfx/drive_c/vrclient`

but not much obviously useful game-side logging.

If necessary later:

- inspect Proton logs more aggressively
- enable a Steam launch option that writes a Proton log for app `1659040`

That has not been done yet in this debugging chain.

## Summary In One Paragraph

The system is much further along than at the start: ALVR wrapper panic fixed, SteamVR repaired after file verification, software encoding enabled to bypass CUDA/NVENC failure, SteamVR content visible in Quest, input restored, Hitman 3 launchable, and VR prompt reachable. The remaining issue is now specifically the Hitman 3 VR handoff. The strongest current hypothesis is that SteamVR UI/Home is interfering when the game exits to restart into VR mode, so the latest untested patch disables both `steamvr.enableHomeApp` and `dashboard.showOnAppExit`. The next step is simply to apply that patch with `snowman dev`, rerun the flow, and confirm from `vrserver.txt` whether SteamVR still launches `openvr.tool.steamvr_environments` after `steam.app.1659040` exits.

