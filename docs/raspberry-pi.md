# Raspberry Pi Setup Guide (Headless)

This guide covers how to bootstrap a headless Raspberry Pi using the official NixOS SD image and integrate it into Snowman.

## 1. Preparation

Download the **generic AArch64 SD Card image** (look for `nixos-sd-image-*-aarch64-linux.img.zst`) from the [NixOS Hydra build server](https://hydra.nixos.org/job/nixos/release-24.05/nixos.sd_image.aarch64-linux).

Flash it to your SD card (replace `/dev/sdX` with your actual device!):

```bash
zstdcat nixos-sd-image-*-aarch64-linux.img.zst | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
````

## 2. The "Surgery" (Headless Injection)

Since you cannot see a screen to log in or configure network, you must inject credentials onto the SD card **before** putting it in the Pi.

1.  **Mount the Card:**
    Unplug and re-plug the SD card to let the kernel refresh the partition table. Mount the main **ROOT** partition (usually partition 2, the larger ext4 one).

    ```bash
    mkdir -p ~/pi_root
    sudo mount /dev/sdX2 ~/pi_root
    ```

2.  **Inject SSH Keys:**
    The default `nixos` user has password `nixos`, but it's safer to use keys immediately.

    ```bash
    # Create SSH directory
    sudo mkdir -p ~/pi_root/home/nixos/.ssh

    # Copy your public key
    cat ~/.ssh/id_ed25519.pub | sudo tee ~/pi_root/home/nixos/.ssh/authorized_keys

    # Fix permissions (UID 1000 is 'nixos' on the image)
    sudo chown -R 1000:100 ~/pi_root/home/nixos
    sudo chmod 700 ~/pi_root/home/nixos/.ssh
    sudo chmod 600 ~/pi_root/home/nixos/.ssh/authorized_keys
    ```

3.  **Inject Wi-Fi Configuration:**
    Create the file `~/pi_root/etc/wpa_supplicant.conf`:

    ```bash
    sudo nano ~/pi_root/etc/wpa_supplicant.conf
    ```

    Paste the following:

    ```text
    ctrl_interface=/var/run/wpa_supplicant
    network={
      ssid="YOUR_WIFI_NAME"
      psk="YOUR_WIFI_PASSWORD"
    }
    ```

4.  **Unmount:**

    ```bash
    sudo umount ~/pi_root
    ```

## 3. First Boot & Harvest

1.  Insert SD card into Pi and power on.
2.  **Wait 3-5 minutes.** The system will resize the partition and generate host keys.
3.  Find the IP address (check router or use `nmap -p 22 --open 192.168.1.0/24`).
4.  SSH in as `nixos` (password is `nixos`, or use keys if injection worked):
    ```bash
    ssh nixos@<IP_ADDRESS>
    ```
5.  Generate the hardware configuration:
    ```bash
    sudo nixos-generate-config
    cat /etc/nixos/hardware-configuration.nix
    ```
    **Copy this output.**

## 4. Snowman Configuration

Back on your workstation:

1.  **Create the Hardware File:**
    Create `hosts/rpi4-hardware-configuration.nix` and paste the config.

2.  **CRITICAL FIX: The Boot Partition:**
    The generated config will try to mount the SD card boot partition to `/boot`. **This is wrong** for the SD image layout because the partition is too small (30MB) to hold NixOS kernels.

    Change `/boot` to `/boot/firmware`:

    ```nix
    # hosts/rpi4-hardware-configuration.nix

    # CHANGE THIS:
    # fileSystems."/boot" = { ... };

    # TO THIS:
    fileSystems."/boot/firmware" =
      { device = "/dev/disk/by-uuid/....";
        fsType = "vfat";
        options = [ "fmask=0022" "dmask=0022" ];
      };
    ```

3.  **Update Inventory:**
    Add the host to `inventory.nix`. Use the `raspberry-pi` firmware type so Snowman configures the correct bootloader (`generic-extlinux-compatible`).

    ```nix
    # inventory.nix
    hosts.rpi4 = {
      system = "aarch64-linux";
      
      # This handles boot.loader.grub = false / generic-extlinux... = true
      hardware.boot.firmware = "raspberry-pi"; 
      
      wifi = {
        mode = "static-wifi";
        networks = [ "home" ];
      };
      
      users = [ "bas" ];
    };
    ```

## 5. Deploy

1.  **Push** your changes to your git repo.
2.  **On the Pi:**
    ```bash
    nix-shell -p git
    git clone <URL_TO_YOUR_REPO> ~/snowman
    cd ~/snowman
    sudo nixos-rebuild switch --flake .#rpi4
    ```
3.  **Reboot:** `sudo reboot`
4.  You can now SSH in as your configured user (`bas`).

-----

## Troubleshooting Common Issues

### "No space left on device" (Boot Partition)

**Symptom:** `cp: error writing '/boot/nixos/...': No space left on device`
**Cause:** You forgot to change `fileSystems."/boot"` to `fileSystems."/boot/firmware"`. NixOS is trying to stuff the kernel into the tiny 30MB FAT partition.
**Fix:**

1.  Update `hardware-configuration.nix` to use `/boot/firmware`.
2.  On the Pi:
    ```bash
    sudo umount /boot
    # Mount temporarily to clean up partial files
    sudo mount /dev/mmcblk0p1 /mnt
    sudo rm -rf /mnt/nixos
    sudo umount /mnt
    ```
3.  Run rebuild again.

### "Warning: do not know how to make this configuration bootable"

**Symptom:** Rebuild finishes, but warns about bootloader. `extlinux.conf` still points to the old installer system.
**Cause:** `hardware.boot.firmware` is not set to `"raspberry-pi"`, so Snowman didn't enable `boot.loader.generic-extlinux-compatible.enable = true`.
**Fix:** Set the inventory option correctly and update your `snowman` engine input if needed.

### "Zombie State" / Lockout

**Symptom:** Installation failed halfway. You rebooted. Now you can't SSH as `nixos` (user deleted) AND you can't SSH as your new user (no keys/password).
**Fix:**

1.  Power down and put SD card in your PC.
2.  Mount root partition.
3.  **Bypass Sudo:** Create `etc/sudoers.d/rescue` with content `myuser ALL=(ALL) NOPASSWD: ALL` (mode 0440).
4.  **Inject Root Keys:** Put your public key in `root/.ssh/authorized_keys` so you can SSH as root if all else fails.
5.  **Force SSH:** Delete `etc/ssh/sshd_config` symlink and replace with a file containing `PermitRootLogin yes`.
