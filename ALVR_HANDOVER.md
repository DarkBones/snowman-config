# ALVR / SteamVR Handover

Date: 2026-03-30
Host: `dorkbones`
User: `bas`
Repo: `/home/bas/snowman-config`

## Current State

The current blocker is still a hard `vrcompositor` startup failure on NixOS.

The latest relevant run was around `2026-03-30 18:36` and showed:

```text
/nix/store/3x81fyw64szwiqwmj38h4hmd44xj2f7n-alvr-20.14.1/libexec/alvr/vrcompositor-wrapper-unwrapped:
symbol lookup error: /lib/libc.so.6: undefined symbol: __nptl_change_stack_perm, version GLIBC_PRIVATE
```

This means:
- ALVR connects far enough for SteamVR to see the headset intermittently.
- SteamVR still cannot keep `vrcompositor` alive.
- The Quest never gets valid rendered frames.
- The desktop black-screen/flicker behavior changed over time, but that was only a symptom. The compositor crash is the root issue.

## What Was Learned

1. Black screen on the Quest is **not** a success state.
2. When the setup works, the Quest should leave the ALVR loading view and show SteamVR Home or the game, and the PC should show a normal SteamVR mirror/compositor window.
3. The earlier SteamVR launch options were wrong for ALVR Linux:
   - Machine had:
     `VALVE_SKIP_RUNTIME_SAFETY=1 /home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%`
   - ALVR Linux wiki says the mandatory workaround is `.../vrmonitor.sh %command%`, and on wlroots/Hyprland-like setups `QT_QPA_PLATFORM=xcb` is a reasonable addition.
4. The latest logs prove the current wrapped package is in use:
   - `~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor`
     points to `/nix/store/3x81fyw64szwiqwmj38h4hmd44xj2f7n-alvr-20.14.1/libexec/alvr/vrcompositor-wrapper`
   - That wrapper currently contains:
     ```bash
     #!/usr/bin/env bash
     exec /nix/store/ja6iax654kbyc4b7vjdvs116960pk1yv-steam-run/bin/steam-run /nix/store/3x81fyw64szwiqwmj38h4hmd44xj2f7n-alvr-20.14.1/libexec/alvr/vrcompositor-wrapper-unwrapped "$@"
     ```
5. Even with that wrapper, SteamVR runtime variables were still leaking through and the unwrapped ALVR compositor binary still hit the same `GLIBC_PRIVATE` crash.

## Repo Changes In Flight

Files changed during this session:
- `modules/alvr.nix`
- `home/roles/gaming.nix`
- `pkgs/alvr-20.13.0.nix`

Important current intent of those changes:

### `modules/alvr.nix`

Uses `pkgsUnstable.alvr.overrideAttrs` instead of the old custom `callPackage ../pkgs/alvr-20.13.0.nix`.

The override appends a `postInstall` wrapper for `libexec/alvr/vrcompositor-wrapper`.

### `home/roles/gaming.nix`

Also uses `pkgsUnstable.alvr.overrideAttrs` for the Home Manager copy of ALVR.

It also rewrites SteamVR launch options in Steam user config to:

```text
QT_QPA_PLATFORM=xcb /home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%
```

It attempts to restore a previously hand-patched `vrcompositor-launcher.sh` from backup if possible, so the repo no longer relies on patching SteamVR internals as the main path.

### `pkgs/alvr-20.13.0.nix`

Was cleaned back up to remove the earlier `steam-run` wrapper experiment. It is no longer the intended package path.

## Most Recent Code Change

The very last change before handoff was to make the generated ALVR wrapper scrub Steam/loader environment variables before calling `steam-run`.

Both `modules/alvr.nix` and `home/roles/gaming.nix` now generate:

```bash
#!/usr/bin/env bash
unset LD_LIBRARY_PATH
unset LD_PRELOAD
unset VRCOMPOSITOR_LD_LIBRARY_PATH
unset STEAM_RUNTIME
unset STEAM_ZENITY
exec ${pkgs.steam-run}/bin/steam-run $out/libexec/alvr/vrcompositor-wrapper-unwrapped "$@"
```

This change was made because the latest logs showed the wrapper itself was now active, but the underlying ALVR compositor still crashed with the same glibc symbol lookup error.

## Important Caveat

The newest env-scrubbing wrapper change was **not** verified against a fresh SteamVR run before this handoff.

A `nix build .#homeConfigurations.bas@dorkbones.activationPackage` was started after this change, but I did not observe it complete before ending the session.

So the next AI should assume:
- the code change exists in the repo
- it may or may not already have been fully built/applied on the machine
- the latest available SteamVR logs are still from the previous wrapper variant, not the env-scrubbed one

## Relevant Local Evidence

### Current `vrcompositor` symlink

```text
~/.local/share/Steam/steamapps/common/SteamVR/bin/linux64/vrcompositor
-> /nix/store/3x81fyw64szwiqwmj38h4hmd44xj2f7n-alvr-20.14.1/libexec/alvr/vrcompositor-wrapper
```

### Latest compositor log timestamp

```text
2026-03-30 18:36:13 ~/.local/share/Steam/logs/vrcompositor-linux.txt
```

### Latest monitor log timestamp

```text
2026-03-30 18:36:25 ~/.local/share/Steam/logs/vrmonitor.txt
```

### Latest server log timestamp

```text
2026-03-30 18:36:36 ~/.local/share/Steam/logs/vrserver.txt
```

### Latest failure pattern

`vrmonitor.txt` shows SteamVR bouncing between:
- `VR_Init failed with Hmd Not Found (108)`
- headset later activates as `alvr_server`
- SteamVR transitions to `Restart`
- then shuts down

That behavior lines up with compositor death causing SteamVR to restart once ALVR finally registers the HMD.

## Web Research Already Done

The next AI does **not** need to rediscover these starting points:

1. ALVR Linux troubleshooting wiki says `vrmonitor.sh %command%` is the required Linux workaround:
   - https://github.com/alvr-org/ALVR/wiki/Linux-troubleshooting
2. There are upstream Linux/NixOS issue reports relevant to this general class of failure:
   - https://github.com/alvr-org/ALVR/issues/2476
   - https://github.com/alvr-org/ALVR/issues/2533

## Recommended Next Steps

1. Check whether the most recent Home Manager build actually finished, or rebuild/apply it explicitly.
2. Apply the newest env-scrubbing wrapper:
   ```bash
   sudo nixos-rebuild switch --flake .#dorkbones --impure
   ```
3. Fully quit Steam.
4. Start Steam again.
5. Confirm SteamVR launch options are still:
   ```text
   QT_QPA_PLATFORM=xcb /home/bas/.local/share/Steam/steamapps/common/SteamVR/bin/vrmonitor.sh %command%
   ```
6. Re-test:
   ```bash
   alvr-dashboard-x11
   ```
   Then connect Quest and launch SteamVR.
7. Immediately inspect fresh timestamps and logs:
   - `~/.local/share/Steam/logs/vrcompositor-linux.txt`
   - `~/.local/share/Steam/logs/vrmonitor.txt`
   - `~/.local/share/Steam/logs/vrserver.txt`
8. If the glibc symbol error still persists even after the env scrub, the next likely direction is to stop using the ALVR compositor wrapper binary as-is and investigate a more forceful runtime boundary fix.

## Things To Avoid Repeating

- Do not go back to the earlier hand-edited `vrcompositor-launcher.sh` approach as the main strategy.
- Do not assume Quest black screen means success.
- Do not assume the problem is networking or headset pairing; the logs consistently point at compositor startup/runtime failure.
