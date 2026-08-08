ls -l /dev/disk/by-id/

usb-Seagate_BUP_Slim_BK_NA9B7GD4-0:0 -> ../../sdc
usb-Seagate_BUP_Slim_BK_NA9B7GD8-0:0 -> ../../sdd

sudo apt update
sudo apt install -y zfsutils-linux

sudo zpool create -f -o ashift=12 storagepool mirror /dev/disk/by-id/usb-Seagate_BUP_Slim_BK_NA9B7GD4-0:0 /dev/disk/by-id/usb-Seagate_BUP_Slim_BK_NA9B7GD8-0:0

sudo zfs create storagepool/data
sudo zfs set compression=lz4 storagepool/data

Your storage is now ready and automatically mounted at /storagepool/data

sudo chown -R y:y /storagepool/data

sudo zfs unmount storagepool/data

sudo zfs unmount -f storagepool/data

sudo zfs mount storagepool/data

sudo zpool upgrade default

sudo zpool status