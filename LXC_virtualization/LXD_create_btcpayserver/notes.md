








# Delete VM and start fresh
lxc stop btcpayserver --force && sudo lxc delete btcpayserver

sudo ./01_host_create_vm_btcpay.sh
sudo lxc exec btcpayserver -- bash /root/02_vm_setup.sh
sudo lxc exec btcpayserver -- bash /root/03_btcpayserver_configure.sh


