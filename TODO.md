## ❌ Why running `nixos-install` from Arch is wrong

From Arch:

* `nixos-install` **does not exist** (unless you’ve hacked it in)
* `nixos-rebuild` **only builds closures and boot entries**
* It **does not populate `/mnt` with a bootable NixOS root**
* You end up with:

  * `/nix/store` full of stuff
  * `/boot` entries created
  * **but `/` has no `/etc`, no `/sbin/init`, no system**
  * → exactly the “switch root contains no usable init” error you saw

So everything you did from Arch was *logically consistent* — just **the wrong execution environment**.

---

## ✅ The rule (burn this into Snowman’s README)

> **`nixos-install` must be run from a NixOS installer environment.
> Never from Arch, never from another distro.**

---

## ✅ What you should do *now* (clean + correct)

You already mounted everything correctly 👍
But you must redo this from the **NixOS installer USB**, not Arch.

### 1️⃣ Reboot into the NixOS installer ISO

Graphical or minimal — doesn’t matter.

---

### 2️⃣ Mount exactly the same layout (from the installer)

From the installer terminal:

```sh
sudo mount /dev/nvme0n1p4 /mnt

sudo mkdir -p /mnt/nix
sudo mount /dev/nvme0n1p5 /mnt/nix

sudo mkdir -p /mnt/boot
sudo mount /dev/nvme0n1p1 /mnt/boot
```

Sanity check:

```sh
mount | rg '/mnt'
```

You should see:

* `/mnt` → p4
* `/mnt/nix` → p5
* `/mnt/boot` → p1

---

### 3️⃣ Run **the one command that actually installs NixOS**

From the installer:

```sh
sudo nixos-install --flake /path/to/snowman-config#dorkbones
```

This step **creates**:

* `/mnt/etc`
* `/mnt/var`
* `/mnt/sbin/init`
* correct `/etc/fstab`
* proper systemd + initrd
* valid boot entries

This is the step you were *never actually doing before*.

---

### 4️⃣ Reboot

```sh
sudo reboot
```

You should now boot cleanly into NixOS **without**:

* “no usable init”
* missing root
* phantom generations

---

## 🔍 Why your mounting output looked “weird” earlier

You saw this:

```
/dev/nvme0n1p4 on /mnt/nixosroot
/dev/nvme0n1p4 on /mnt
```

That’s just a leftover mount point from earlier experiments.
It’s harmless — but another sign the install process was never clean.

After a real `nixos-install`, `/mnt` will contain a full OS tree.

---

## 🧠 Snowman design takeaway (important for your project)

For Snowman to be “install → pull config → rebuild → done”, you must enforce:

* **First install always uses `nixos-install`**
* `nixos-rebuild` is *post-install only*
* Never support “install from Arch” as a workflow

This isn’t user error — this is a **sharp edge in NixOS** that Snowman should explicitly guard against.

---

If you want, next we can:

* Add a **Snowman preflight check** that refuses to run on non-NixOS
* Formalize the **installer vs rebuild** phases in your docs
* Or automate the whole thing via a Snowman installer script

But first: boot the installer and run `nixos-install`.
That’s the missing keystone.

