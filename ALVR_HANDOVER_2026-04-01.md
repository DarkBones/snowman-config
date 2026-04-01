# ALVR / SteamVR Handover

Date: 2026-04-01
Host: `dorkbones`
User: `bas`
Repo: `/home/bas/snowman-config`

## Current Status

ALVR on Linux is still not working end-to-end.

The current situation is:

- Steam client launches again.
- SteamVR launch options are being managed by Home Manager.
- `vrwebhelper` was failing earlier due to an old `libnss3`, and that specific failure is now fixed.
- The remaining blocker is still `vrcompositor` crashing with the glibc private symbol error.
- On the most recent run, ALVR activates the headset, then SteamVR restarts because compositor startup fails.
- Quest stays black.
- ALVR dashboard becomes unresponsive shortly after clicking `Start SteamVR`.

## Most Recent Confirmed Failure

Freshest relevant run:

- `2026-04-01 14:17:09` in `~/.local/share/Steam/logs/vrcompositor-linux.txt`

The failure is:

```text
/home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor:
symbol lookup error: /lib/libc.so.6: undefined symbol: __nptl_change_stack_perm, version GLIBC_PRIVATE
```

This is still the root blocker.

## What Changed During This Session

### 1. Reverted the broken ALVR package override

The earlier custom `steam-run` wrapper inside the ALVR package caused a new panic:

```text
Failed to read vrcompositor symlink: Invalid argument (os error 22)
```

That override was removed so the repo now uses stock `pkgsUnstable.alvr` again.

Files:

- `modules/alvr.nix`
- `home/roles/gaming.nix`

### 2. Updated SteamVR launch options for Wayland/wlroots and hybrid graphics

Home Manager now rewrites SteamVR launch options to:

```text
__NV_PRIME_RENDER_OFFLOAD=1 __VK_LAYER_NV_optimus=NVIDIA_only __GLX_VENDOR_LIBRARY_NAME=nvidia VK_DRIVER_FILES=/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.x86_64.json WAYLAND_DISPLAY= QT_QPA_PLATFORM=xcb /home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%
```

Reasoning:

- upstream ALVR Linux wiki requires `vrmonitor.sh %command%`
- wlroots/Hyprland guidance supports `QT_QPA_PLATFORM=xcb`
- this machine is hybrid graphics:
  - NVIDIA RTX 4080 SUPER
  - AMD Raphael iGPU
- ALVR Linux troubleshooting says AMD/Intel iGPU + NVIDIA dGPU setups may need PRIME offload vars and explicit NVIDIA Vulkan ICD selection

### 3. Added a managed patch for SteamVR `vrwebhelper.sh`

Fresh run on 2026-04-01 exposed this failure:

```text
./vrwebhelper: ...libnss3.so: version `NSS_3.30' not found
./vrwebhelper: ...libnss3.so: version `NSS_3.31' not found
```

This came from SteamVR using an older Steam runtime `libnss3` for `vrwebhelper`.

Home Manager now patches:

- `~/.local/share/Steam/steamapps/common/SteamVR/bin/vrwebhelper/linux64/vrwebhelper.sh`

to prepend:

```text
/run/current-system/sw/share/nix-ld/lib
```

to `LD_LIBRARY_PATH` before launching `vrwebhelper`.

This fix appears to work:

- the `NSS_3.30` / `NSS_3.31` errors disappeared on the latest run
- `vrwebhelper` now connects successfully in `vrserver.txt`

## Current Repo State / Intended Behavior

### `home/roles/gaming.nix`

This file now does all of the following:

- uses stock `pkgsUnstable.alvr`
- keeps `alvr-dashboard-x11` as a fallback wrapper
- ensures `~/.config/alvr/session.json` exists and controller settings are forced off
- rewrites SteamVR launch options in Steam `localconfig.vdf`
- restores a previously hand-patched `vrcompositor-launcher.sh` from backup if detected
- patches `vrwebhelper.sh` to use the newer system `nss`

### `modules/alvr.nix`

This now also uses stock `pkgsUnstable.alvr` instead of the previous `overrideAttrs` wrapper attempt.

## Validation Status

At end of session, both builds passed again:

```bash
nix build .#homeConfigurations.bas@dorkbones.activationPackage
nix build .#nixosConfigurations.dorkbones.config.system.build.toplevel --impure
```

`snowman dev` had temporarily failed because the first `vrwebhelper.sh` patch implementation had activation-time quoting bugs.

Those activation bugs were fixed.

## Local Evidence From Latest Run

### SteamVR launch options are active

The Steam app launch options for SteamVR were previously confirmed in local Steam userdata as:

```text
WAYLAND_DISPLAY= QT_QPA_PLATFORM=xcb /home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%
```

Later repo changes expanded that to the PRIME + Vulkan ICD string above.

### Current `vrcompositor` symlink

As of latest inspection:

```text
~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor
-> /nix/store/m77cczgk75sndpylc8cc470s9yjwba4d-alvr-20.14.1/libexec/alvr/vrcompositor-wrapper
```

### Latest `vrserver` behavior

On latest run:

- `vrwebhelper` starts and connects
- `alvr_server` driver loads
- headset eventually activates
- `vrserver` then transitions to restart

Important timestamp:

- `2026-04-01 14:17:09`

### Latest `vrmonitor` behavior

On latest run:

- SteamVR starts normally
- headset becomes `alvr_server`
- state changes from `NotReady` to `Restart`
- then SteamVR shuts down

### Latest `vrcompositor` behavior

Fresh log entries exist again, and they show the old glibc crash:

```text
[2026-04-01 14:17:09] /home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor:
symbol lookup error: /lib/libc.so.6: undefined symbol: __nptl_change_stack_perm, version GLIBC_PRIVATE
```

## Important Conclusions

### Things that are no longer the main blocker

- not pairing / networking
- not missing ALVR driver registration
- not `vrwebhelper` `libnss3` mismatch anymore
- not Steam client startup anymore

### Remaining blocker

The remaining blocker is specifically the ALVR compositor path on NixOS:

- SteamVR launches `vrcompositor`
- that path resolves to ALVR’s `vrcompositor-wrapper`
- startup still dies with the old glibc symbol failure

## What Not To Repeat

### Do not reintroduce the earlier package override as-is

The earlier approach that replaced ALVR’s packaged `vrcompositor-wrapper` with a `steam-run` shell wrapper produced:

```text
Failed to read vrcompositor symlink: Invalid argument (os error 22)
```

So that specific implementation should not be restored blindly.

### Do not assume `vrwebhelper` is still the issue

That issue was real, but the latest logs suggest it is fixed.

### Do not assume black Quest screen means partial success

The logs still show compositor death / SteamVR restart, which means rendered frames are still not being produced correctly.

## Best Next Step

The next likely useful step is:

### Create a separate external `vrcompositor` wrapper instead of overriding the package binary

Reasoning:

- Stock ALVR package path avoids the symlink panic.
- Stock ALVR package path still hits the glibc symbol failure.
- The old direction of scrubbing Steam runtime env before launching ALVR was probably correct, but the implementation point was wrong.

Recommended next approach:

1. Leave the packaged ALVR `vrcompositor-wrapper` binary untouched.
2. Create a standalone shell wrapper outside the package, probably in Home Manager.
3. Have SteamVR `bin/linux64/vrcompositor` point to that wrapper instead of directly to ALVR’s wrapper.
4. In that wrapper:
   - unset or scrub Steam runtime loader variables such as:
     - `LD_LIBRARY_PATH`
     - `LD_PRELOAD`
     - `VRCOMPOSITOR_LD_LIBRARY_PATH`
     - maybe `STEAM_RUNTIME`
   - then exec the packaged ALVR `vrcompositor-wrapper`
5. Avoid modifying SteamVR `vrcompositor-launcher.sh` as the primary strategy if possible.

The key difference from the broken attempt:

- do not replace ALVR’s internal wrapper binary in the Nix store
- instead, wrap it externally and keep the original ALVR binary intact

## Useful Commands / Paths

### Logs

- `~/.local/share/Steam/logs/vrcompositor-linux.txt`
- `~/.local/share/Steam/logs/vrmonitor.txt`
- `~/.local/share/Steam/logs/vrserver.txt`
- `~/.steam/steam/logs/console-linux.txt`

### Current SteamVR path

- `~/.local/share/Steam/steamapps/common/SteamVR`

### Current ALVR session file

- `~/.config/alvr/session.json`

## Files Changed In Repo This Session

- `home/roles/gaming.nix`
- `modules/alvr.nix`

## External References Already Used

- ALVR Linux Troubleshooting wiki:
  - https://github.com/alvr-org/ALVR/wiki/Linux-Troubleshooting
- ALVR general Troubleshooting wiki:
  - https://github.com/alvr-org/ALVR/wiki/Troubleshooting

## Final Summary

At end of session:

- Steam launches
- `vrwebhelper` launches
- ALVR driver loads
- headset activates
- SteamVR still restarts because `vrcompositor` dies with the old glibc symbol lookup error

The next session should focus directly on replacing the `vrcompositor` entrypoint with a safe external wrapper that scrubs the Steam runtime environment before invoking ALVR’s packaged compositor wrapper.
