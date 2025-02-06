#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
set -e

. $(dirname "$0")/config.sh

# This script builds a tiny rescue initramfs with bash as init and
# busybox for helper functions. Use it for quick kernel debugging.

OUT="$1"
BINARIES="bash busybox sleep ip brctl tcpdump $QEMU_BUILD_DIR/qemu-system-x86_64 $QEMU_BUILD_DIR/qemu-bridge-helper strace trace-cmd $3"

for i in $BINARIES; do
    if ! which $i &>/dev/null; then
        echo "Cound not find '$i', please install it and rerun" >&2
        exit 1
    fi
done

if [ ! "$OUT" ]; then
    echo "Syntax: $0 <output file> <init script dir> <binaries>"
    exit 1
fi

TMPDIR=$(mktemp -d)

(
    set -e

    ROOTDIR=$(pwd)
    cd $TMPDIR

    # Create directory structure
    for dir in bin lib proc sys etc etc/init.d root tmp usr; do
        mkdir $dir
    done
    ln -s lib lib64
    ln -s /lib lib/x86_64-linux-gnu
    ln -s /proc/mounts etc/mtab

    # Install all binaries
    for i in $BINARIES; do
        cp $(cd $ROOTDIR; which $i) bin/
    done

    # Copy all required libs
    for i in $BINARIES; do
        [[ $i = *bzImage ]] && continue
        [[ $i = *initrd ]] && continue

        for f in $(ldd bin/$(basename $i) 2>&1 | grep -v 'not a dynamic executable' | cut -d '(' -f 1 | cut -d '>' -f 2 | grep -v vdso); do
            cp $f lib/
        done
    done

    # Populate busybox helpers
    for f in $(busybox --list); do
        # Use system binaries if available instead
        if [ -f "bin/$f" ]; then
            continue
        fi
        ln -s busybox bin/$f
    done

    # Populate init files
    cp $ROOTDIR/inittab etc/inittab
    cp $ROOTDIR/rcS etc/init.d/rcS
    cp bin/init .
    echo "root::0:0:root:/root:/bin/sh" > etc/passwd
    cp $ROOTDIR/config.sh .
    cp $ROOTDIR/run.sh .
    cp $ROOTDIR/dhcp-client-script.sh .
    cp $ROOTDIR/run_br0.sh .
    mkdir -p etc/qemu
    echo "allow br0" > etc/qemu/bridge.conf

    # Install QEMU add-ons if needed
    if [[ $BINARIES = *qemu* ]]; then
        mkdir -p usr/share
        ln -s / usr/share/qemu
        ln -s / keymaps
        for file in bios.bin vgabios.bin bios-256k.bin vgabios-stdvga.bin kvmvapic.bin linuxboot_dma.bin efi-e1000.rom efi-vmxnet3.rom keymaps/en-us; do
            for dir in /usr/share/qemu /usr/share/seabios /usr/share/seavgabios /usr/share/ipxe/qemu; do
                [ -e $dir/$file ] || continue
                cp $dir/$file .
            done
        done
    fi
    cp $ROOTDIR/multiboot_dma.bin .
    cp /usr/share/OVMF/OVMF_CODE.fd .
    cp $ROOTDIR/*.fd .

    # Install gdb
    cp $ROOTDIR/gdb* bin/gdb
    cp $ROOTDIR/.gdbinit .

    # kvm-unit-tests
    if [ $KVM_UNIT_TESTS_BUILD_DIR ]; then
	    mkdir kvm-unit-tests
	    cp $KVM_UNIT_TESTS_BUILD_DIR/tests/* kvm-unit-tests/.
    fi

    # generate cpio archive
    find . | cpio -H newc -o
) > $OUT

# Clean up
rm -rf $TMPDIR
