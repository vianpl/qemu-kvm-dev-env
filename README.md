QEMU/KVM Development Tools
--------------------------

This repository contains a few helper scripts that make use of nested
virtualization to simplify experimentation with Linux and QEMU's virtualization
interfaces. Once configured, as detailed in `config.sh`, it allows launching a
development kernel using the system's QEMU. Within that virtual machine, an
initrd containing the development QEMU binary is loaded, and ultimately a test
operating system is booted using the development QEMU binary. This allows to
quickly test new virtualization interfaces, without having to go through the
hassle of installing new kernels on real systems. For more information see the
usage section at the bottom.

## Setup

Install dependencies, validated on Fedora 41:

```
$ sudo dnf in -y @development-tools
$ sudo dnf in -y ninja bzip2 pixman-devel libslirp-devel openssl-devel-engine python3-libtmux \
      busybox strace trace-cmd edk2-ovmf qemu-system-x86 nc expect tmux git bc telnet
```

Copy the following into /etc/udev/rules.d/kvm-user.rules, update "GROUP" to
match the user's:
```
KERNEL=="kvm", GROUP="fedora", MODE="0660"
KERNEL=="vhost-vsock", GROUP="fedora", MODE="0660"
KERNEL=="vhost-net", GROUP="fedora", MODE="0660"
```

Then run:
```
sudo udevadm control --reload-rules && sudo udevadm trigger
```
Build an up-to-date copy of QEMU:

```
$ git clone https://github.com/vianpl/qemu.git
$ cd qemu
$ git checkout vsm/next
$ ./configure --target-list=x86_64-softmmu --enable-debug --enable-trace-backends=ftrace
$ make -j$(nproc)
$ cd -
```

Build a kernel for testing:

```
$ git clone https://github.com/vianpl/linux.git
$ cd linux
$ git checkout vsm/next
$ make defconfig
$ ./scripts/config --enable CONFIG_BLK_DEV_NVME --enable CONFIG_KVM --enable CONFIG_KVM_INTEL
$ make olddefconfig
$ make -j$(nproc) bzImage
$ cd -
```
[Optional] Build kvm-unit-tests:
```
$ git clone https://github.com/vianpl/kvm-unit-tests.git
$ cd kvm-unit-tests-vsm
$ git checkout vsm/next 
$ ./configure
$ make -j$(nproc) standalone
$ cd -
```

Pull this repository and update `config.sh`:
```
$ git clone https://github.com/vianpl/qemu-kvm-dev-env.git
$ cd qemu-kvm-dev-env
$ # Here's where 'config.sh' gets updated...
```
## Usage

Finally, run it all:

```
$ # Launch a tmux senssion
$ tmux
$ # Run it!
$ ./run_tmux.py
```

If successful, it should output like this (QEMU host monitor is not exposed as
I couldn't find a usage for it):

 ```
 +--------------------------------+
 |                |               |
 | QEMU Guest     | Guest         |
 | monitor        | Console       |
 |                |               |
 +----------------+---------------+
 |                |               |
 | Host           | Guest         |
 | Shell          | Shell         |
 |                |               |
 +----------------+---------------+
 ```

The guest shell will be take a while to show up, as long as it's booting.

VNC and RDP are forwarded to their default ports. So connecting from your
laptop through TigerVNC or Microsoft Remote Desktop should be as easy as
inputting your dev machine's IP addres. VNC is specially useful when the guest
struggles with booting, RDP is only available after booting completely.

When configured correctly kvm-unit-tests are available in `./kvm-unit-tests`
each test will run as a standalone binary. One can run the whole suite and save
the results on the host machine as such:
```
for b in $(ls); do ./$b | tee -a ../host/results-clean.txt; done
```
It's possible to launch `kvm-unit-tests` instead of the default qcow2 image
using the follwoing option: `./run_tmux.py --unit hyperv-vsm`

In case debugging is necessary `run_tmux.py` has the following options:
- `--gdb`: qemu will not start until the user sends the `run` command in the
  gdb console. Not compatible with kvm-unit-tests.
- `--trace`: traces are gathered until qemu stops or it's interrupted with
  ctrl-C. Traces will be available in `qemu-kvm-dev-env/share`.

## TODO

- perf binary
- Try to reconnect ssh after reboot
- KVM selftests, for now:
```
$ make -C tools/testing/selftests TARGETS=kvm INSTALL_PATH=/home/nsaenz/c/qemu-kvm-dev-env/share/ CC=clang -j100 install
```
