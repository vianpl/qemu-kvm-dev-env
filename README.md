QEMU/KVM Development Tools
--------------------------

This repo contains a few helper scripts that make use of nested virtualization
to simplify experimentation with Linux and QEMU's virtualization interfaces.
Once configured, as detailed in `config.sh`, it allows launching a development
kernel using the system's QEMU. Within that virtual machine, an initrd
containing the development QEMU binary is loaded, and ultimately a test
operating system is booted using the development QEMU binary. This allows to
quickly test new virtualization interfaces, without having to go through the
hassle of installing new kernels on real systems. For more information see the
usage section at the bottom.

## Setup

Install dependencies, validated on AL2 (rhel7): 

```
$ sudo yum groupinstall -y 'Development Tools'
$ sudo yum install -y https://rpmfind.net/linux/epel/next/8/Everything/x86_64/Packages/b/busybox-1.35.0-2.el8.next.x86_64.rpm
$ sudo yum install -y glib2-devel pixman-devel clang openssl-devel trace-cmd qemu ncurses-devel telnet tmux expect nc
$ sudo python3 -m pip install meson
$ sudo python3 -m pip install ninja

$ # Install libslirp (Only necessary on AL2/rhel7, on modern distros install
$ # libslirp through the package manager)
$ #
$ git clone https://gitlab.freedesktop.org/slirp/libslirp
$ cd libslirp
$ meson build
$ # Install libslirp
$ sudo $(whereis ninja | cut -d" " -f 2) -C build install 
$ # Install pkgconfig files, necessary for QEMU to find libslirp
$ sudo cp build/meson-private/slirp.pc /usr/share/pkgconfig/.
$ # Let ld know where libslirp lives
$ echo "/usr/local/lib64" | sudo tee /etc/ld.so.conf.d/libslirp.conf
$ sudo ldconfig
$ cd -
```
Build an up-to-date copy of QEMU (AL2's gcc is too old):

```
$ git clone git@github.com:vianpl/qemu.git
$ cd qemu
$ git checkout vsm-rfc-v1   # Optional
$ ./configure --target-list=x86_64-softmmu --cc=clang --cxx=clang --enable-debug --enable-trace-backends=ftrace
$ make -j$(nproc)
$ cd -
```

Build a kernel for testing:

```
$ git clone git@github.com:vianpl/linux.git
$ cd linux
$ git checkout vsm-rfc-v1   # Optional
$ make defconfig
$ ./scripts/config --enable CONFIG_BLK_DEV_NVME --enable CONFIG_KVM --enable CONFIG_KVM_INTEL
$ make olddefconfig
$ make -j$(nproc) CC=clang bzImage
$ cd -
```
This gives you a working kernel image.

[Optional] Build kvm-unit-tests:
```
$ git clone git@github.com:vianpl/kvm-unit-tests.git
$ cd kvm-unit-tests-vsm
$ git checkout vsm-rfc-v1   # Optional
$ ./configure
$ make -j$(nproc) standalone
$ cd -
```

Ultimately update `config.sh`, and build the initrd:

```
$ ./mkinitramfs.sh initrd
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
