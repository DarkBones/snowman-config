## 1. Hardware import on fresh systems

**What hurt:**

* On the Pi SD image there was **no `/etc/nixos/hardware-configuration.nix`**, so:

  * `snowman-import-hardware` failed.
  * You had to manually run `nixos-generate-config`, then re-run the script.

**Low-risk improvement:**

* Make `bin/snowman-import-hardware` *self-healing*:

  ```sh
  if [ ! -f /etc/nixos/hardware-configuration.nix ]; then
    echo "[snowman] /etc/nixos/hardware-configuration.nix missing, running nixos-generate-config..."
    nixos-generate-config --no-config
  fi
  ```

  Then copy the file.
  That would have turned your “what the hell, why is this missing?” moment into:

  > Oh, it just generated it for me and copied it.

---

## 2. SOPS / age key onboarding for a new host

**What hurt:**

* Finding `ssh-to-age` (wrong package at first).
* Manually:

  * extracting age key,
  * editing `.sops.yaml` in the engine,
  * remembering to add `*rpi4` to the right `creation_rules`,
  * running `sops updatekeys` in the config repo.

**Improvements:**

1. **Doc-level**: a “New host secrets checklist” section in the template README, something like:

   1. On the host:
      `nix-shell -p ssh-to-age --run 'ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub'`
   2. In `snowman/.sops.yaml`: paste as `&rpi4`, add `*rpi4` to creation rules.
   3. In snowman-config: `sops updatekeys users/secrets/bas_secrets.yml`.
   4. `git push` both repos, then `nixos-rebuild`.

2. **Tooling** (optional later): a helper like `bin/snowman-host-age-snippet` in the *config* repo that prints exactly what to paste:

   ```sh
   # On host
   ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub \
     | sed 's/^/    - \&rpi4 /'
   ```

   And maybe a little `HOWTO: paste this under &users → creation_rules`.

That keeps the engine pure but gives you “do these 3 commands” instead of tribal knowledge.

---

## 3. Raspberry Pi / ARM bootstrap ergonomics

**What hurt:**

* Figuring out:

  * which ARM image to download (Hydra URL voodoo),
  * that you drop `configuration.nix` into the FAT partition for Wi-Fi + SSH,
  * and that the “Warning: do not know how to make this configuration bootable” is harmless in Pi-land.

**Improvements:**

1. **Template docs**: a short `docs/rpi4.md` or a section in README:

   * exact `wget` URL for the sd image,
   * sample `configuration.nix` for headless Wi-Fi + SSH,
   * explicit “then: clone snowman-config, run `snowman-import-hardware`, add host key, switch”.

2. **Optional nice-to-have**: expose sdImage builds from the config flake, e.g.:

   ```nix
   # in config flake outputs:
   sdImages.rpi4 = self.nixosConfigurations.rpi4.config.system.build.sdImage;
   ```

   So on your dev machine you can do:

   ```sh
   nix build .#sdImages.rpi4
   sudo dd if=result/sd-image/*.img of=/dev/sdX ...
   ```

   That would skip the whole “find the right Hydra URL” step altogether.

---

## 4. Minor QoL bits

A couple of small things that surfaced:

* **`snowman-import-hardware` message** could explicitly mention “If this is a live SD image, I’ll run `nixos-generate-config` for you” once you add that behavior.
* For ARM/Pi hosts, maybe a tiny Snowman module that sets a Pi-appropriate `boot.loader` and suppresses the scary but harmless:

  > Warning: do not know how to make this configuration bootable

  Even if it’s just:

  ```nix
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.generic-extlinux-compatible.enable = lib.mkDefault true;
  ```

  gated behind `hardware.boot.firmware = "efi" | "none" | "pi"` or a `profile = "rpi4"`.

---

If I had to prioritize **what’s worth changing now** with minimal churn:

1. **Auto `nixos-generate-config` in `snowman-import-hardware`**
2. **Add a small “New host + sops” section to the README / template**
3. **Add an `rpi4` doc section with the exact sd-image URL + bootstrap config**

Those three alone would have shaved off most of the confusion from what you just did, without touching Snowman’s core abstractions at all.

