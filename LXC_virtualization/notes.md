



```


sudo snap install lxd

sudo lxd init

Would you like to use LXD clustering? (yes/no) [default=no]: 
Do you want to configure a new storage pool? (yes/no) [default=yes]: 
Name of the new storage pool [default=default]: 
Name of the storage backend to use (btrfs, ceph, dir, lvm, powerflex, zfs, pure) [default=zfs]: 
Create a new ZFS pool? (yes/no) [default=yes]: 
Would you like to use an existing empty block device (e.g. a disk or partition)? (yes/no) [default=no]: 
Size in GiB of the new loop device (1GiB minimum) [default=30GiB]: 
Would you like to connect to a MAAS server? (yes/no) [default=no]: 
Would you like to create a new local network bridge? (yes/no) [default=yes]: 
What should the new bridge be called? [default=lxdbr0]: 
What IPv4 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: 
What IPv6 address should be used? (CIDR subnet notation, “auto” or “none”) [default=auto]: none
Would you like the LXD server to be available over the network? (yes/no) [default=no]: yes
Address to bind LXD to (not including port) [default=all]: 
Port to bind LXD to [default=8443]: 
Would you like stale cached images to be updated automatically? (yes/no) [default=yes]: 
Would you like a YAML "lxd init" preseed to be printed? (yes/no) [default=no]: 






sudo lxc launch ubuntu-minimal:24.04 my-tiny-vm --vm \
  -c limits.cpu=1 \
  -c limits.memory=512MiB \
  -d root,size=4GiB


sudo lxc launch images:ubuntu/24.04/desktop my-small-desktop --vm \
  -c limits.cpu=1 \
  -c limits.memory=2GiB \
  -d root,size=10GiB \
  --console=vga





sudo lxc list

sudo lxc exec my-tiny-vm -- bash

sudo lxc config set core.https_address :8443

https://localhost:8443 


sudo ufw allow from 192.168.3.0/24 to any port 8443 proto tcp



sudo apt install virt-viewer
sudo lxc console my-small-desktop --type vga


sudo rsync -ahS --progress /var/lib/libvirt/images/server.qcow2 /path/to/external_device/




```

```
laptop LXD cert

eyJjbGllbnRfbmFtZSI6Imx4ZC11aSIsImZpbmdlcnByaW50IjoiMjI2Njg0ODczMTkzNWRhYTY5OTc0NDE1MTBjZDdiZjI3ZDEzNWU3Mjk1NDJjMWQyYjJjNGYxN2Y3ZGM3ZDkwOSIsImFkZHJlc3NlcyI6WyIxOTIuMTY4LjEyMi4xOjg0NDMiLCIxNzIuMTcuMC4xOjg0NDMiLCIxOTIuMTY4LjMuMTI6ODQ0MyIsIjEwLjY5LjIxNS4xOjg0NDMiXSwic2VjcmV0IjoiZmNlZDBkMzNmMzMzYmE0ZmQ1NDVkYmZiOTFjOTQ3Njc2YzYyYzk0MjBlZDkzYWU1ZTBkNjk0OGYyZGY5NTkyZCIsImV4cGlyZXNfYXQiOiIwMDAxLTAxLTAxVDAwOjAwOjAwWiIsInR5cGUiOiJDbGllbnQgY2VydGlmaWNhdGUifQ==


```


```
box LXD cert 

sudo lxc auth identity create tls/lxd-ui --group admins
TLS identity "tls/lxd-ui" (cea06ffa-d347-419d-81e7-8c453b5d4041) pending identity token:
eyJjbGllbnRfbmFtZSI6Imx4ZC11aSIsImZpbmdlcnByaW50IjoiOTNiYTcwYzU1OGIxZTg0M2ZkOTkxMjM1YzZmZjMwZTZhZWYyNDJiNDE5YjZjOTg4OThmZjc1OTBiYjA3NzA1MiIsImFkZHJlc3NlcyI6WyIxOTIuMTY4LjMuMTY6ODQ0MyIsIjE5Mi4xNjguMTIyLjE6ODQ0MyIsIjE3Mi4xNy4wLjE6ODQ0MyIsIjEwLjk1LjE4Mi4xOjg0NDMiXSwic2VjcmV0IjoiMjUzZDc4ZDQ4ZjRkNWM3ODU1MmFhYWMxNjEzODMzODNhODE5NGU0NmMyMzA0OTA2ZjA4NjM0MTA1NGI5YmVkZiIsImV4cGlyZXNfYXQiOiIwMDAxLTAxLTAxVDAwOjAwOjAwWiIsInR5cGUiOiJDbGllbnQgY2VydGlmaWNhdGUifQ==

```





```

https://github.com/canonical/lxd/releases/tag/lxd-6.7


chmod +x bin.linux.lxd-convert.x86_64


sudo snap refresh lxd --channel=latest/stable






```

