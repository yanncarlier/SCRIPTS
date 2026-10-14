



https://github.com/firecracker-microvm/firecracker/releases/  

## Installing and running a Firecracker microVM on Ubuntu 26

Firecracker needs KVM, so check that first:

```
ls -l /dev/kvm
```

### 1. Install Firecracker and build the VM image

```
chmod +x setup.sh && ./setup.sh
```

### 2. Boot the microVM

```
run-vm.sh 
```

### 3. Connect to the VM

```
connect.sh
```

Usage

```
chmod +x run-vm.sh connect.sh

# Terminal 1
./run-vm.sh

# Terminal 2
./connect.sh
```

