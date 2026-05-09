# Taskwarrior 3 / TaskChampion Sync

This repo now uses Taskwarrior 3 and TaskChampion sync.

Old Taskwarrior 2 `taskd`/Taskserver is not protocol-compatible with Taskwarrior 3.
There is no server-side conversion from `/var/lib/taskserver`; migrate by importing the
Taskwarrior 2 data on one fully synced client, then seeding the new TaskChampion server
from that client.

## Repo Wiring

On clients, `home/roles/taskwarrior.nix` installs `taskwarrior3` and writes `~/.taskrc`
with:

```ini
sync.server.url=http://100.126.175.104:53589
sync.server.client_id=c97db027-a4d3-4ff9-9e8e-ac4d1987399a
include ~/.task/sync.rc
```

The included `~/.task/sync.rc` is rendered locally at activation time from SOPS because
it contains the shared sync encryption secret:

```ini
sync.encryption_secret=<same secret on every replica>
```

The encrypted value lives in `users/secrets/bas_secrets.yml` as
`taskwarrior_sync_encryption_secret`. On NixOS clients, Snowman exposes it through
`/run/secrets/taskwarrior_sync_encryption_secret`. On standalone Home Manager clients
such as macOS, the activation script decrypts the same SOPS file with the local SSH key.

On rpi4, `modules/taskserver.nix` now runs `taskchampion-sync-server` on port 53589 with
SQLite storage in `/var/lib/taskchampion-sync-server`. The filename is kept for the
existing inventory reference; the service inside it is no longer old Taskserver. The
server is plain HTTP; keep it on Tailscale/LAN or put it behind a TLS reverse proxy
before exposing it publicly.

## Migration Procedure

### 1. Drain old Taskserver

Before rebuilding anything, run this on every Taskwarrior 2 client that might have local
changes:

```bash
task sync
task count
```

Resolve any old sync errors first. Pick one fully synced machine as the migration source;
normally `dorkbones`.

### 2. Back up old data

On the migration source:

```bash
stamp="$(date +%Y%m%d-%H%M%S)"
cp -a ~/.task ~/.task.backup-taskwarrior2-"$stamp"
cp -a ~/.taskrc ~/.taskrc.backup-taskwarrior2-"$stamp"
```

On rpi4, optional but recommended:

```bash
sudo cp -a /var/lib/taskserver /var/lib/taskserver.backup-taskwarrior2-"$(date +%Y%m%d-%H%M%S)"
```

### 3. Deploy rpi4

Rebuild rpi4 so it runs TaskChampion instead of old Taskserver:

```bash
nix run nixpkgs#nixos-rebuild -- switch \
  --flake ~/snowman-config#rpi4 \
  --target-host bas@rpi4 \
  --use-remote-sudo
```

Check it:

```bash
ssh bas@rpi4 'systemctl status taskchampion-sync-server --no-pager'
```

### 4. Deploy the primary client

Rebuild the primary client, then create the local sync secret:

```bash
snowman dev

secret="$(head -c 48 /dev/urandom | base64 -w0)"
printf 'sync.encryption_secret=%s\n' "$secret" > ~/.task/sync.rc
chmod 600 ~/.task/sync.rc
```

Save that value into `users/secrets/bas_secrets.yml` under
`taskwarrior_sync_encryption_secret`, then rebuild each client so Home Manager renders
`~/.task/sync.rc` from SOPS.

### 5. Import Taskwarrior 2 data

On the primary client:

```bash
task import-v2 rc.hooks=0
task count
```

Taskwarrior 3 stores tasks in `~/.task/taskchampion.sqlite3`. The old `*.data` files can
be moved out of `~/.task` after you have verified the import and backup.

### 6. Seed the new server

On the primary client:

```bash
task sync
```

Do not use `task sync init`; that was for old `taskd`.

### 7. Add other replicas

For every other machine, rebuild it, then start from an empty Taskwarrior 3 data
directory and pull from the server:

```bash
stamp="$(date +%Y%m%d-%H%M%S)"
mv ~/.task ~/.task.backup-taskwarrior2-"$stamp"
mkdir -p ~/.task
snowman dev
task sync
```

The Snowman config keeps `recurrence=on` on `dorkbones` and `recurrence=off` on the other
replicas to avoid duplicate recurring task generation.

## After Cutover

Once all replicas sync successfully:

```bash
task diagnostics
task sync
```

Old client certificate files under `~/.task/keys` and the rpi4 `/var/lib/taskserver`
backup are no longer used by Taskwarrior 3.
