{
  disko.devices = {
    disk.sdCard = {
      type = "disk";
      device = "/dev/mmcblk1";
      content = {
        type = "gpt";
        partitions = {
          boot = {
            type = "partition";
            size = "512M";
            start = "1M";
            label = "BOOT";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "defaults" "flush" ];
            };
          };

          root = {
            type = "partition";
            size = "100%";
            label = "ROOT";
            content = {
              type = "filesystem";
              format = "ext4";
              mountpoint = "/";
              mountOptions = [ "noatime" "discard" ];
            };
          };
        };
      };
    };
  };
}
