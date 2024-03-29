#!/bin/bash

export QEMU_BUILD_DIR="/home/nsaenz/c/qemu/build"
export KERNEL_BUILD_DIR="/home/nsaenz/c/linux"
export KVM_UNIT_TESTS_BUILD_DIR="/home/nsaenz/c/kvm-unit-tests"

export WORK_DIR="/home/nsaenz/c/qemu-kvm-dev-env"
export GUEST_IMAGE="$WORK_DIR/../qemu-kvm-dev-disk-images/windows-server-2016.qcow2"

# No need to change the defines below, the defaults should be mostly fine
export SHARE_DIR="$WORK_DIR/share"
export INITRD_PATH="$WORK_DIR/initrd"

export SSH_USER="Administrator"
export SSH_PASSWORD="f6A6nqdFHfBng"
export SSH_PORT="8000"

export HOST_TELNET_PORT="1237"
export GUEST_CONSOLE_PORT="1235"
export GDB_PORT="1234"
