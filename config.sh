#!/bin/bash

export ROOT_DIR="/home/nsaenz/c/"
export QEMU_BUILD_DIR="$ROOT_DIR/qemu/build"
export KERNEL_BUILD_DIR="$ROOT_DIR/linux"
export KVM_UNIT_TESTS_BUILD_DIR="$ROOT_DIR/kvm-unit-tests"
export WORK_DIR="$ROOT_DIR/qemu-kvm-dev-env"

# L2 Guest config
export CPUS="8"
export MEM="32G"
export GUEST_IMAGE="$WORK_DIR/../win-images/win22-no-cg.qcow2"
export SSH_USER="Administrator"
export SSH_PASSWORD="f6A6nqdFHfBng"

# No need to change the defines below, the defaults should be mostly fine
export SHARE_DIR="$WORK_DIR/share"
export INITRD_PATH="$WORK_DIR/initrd"

export HOST_TELNET_PORT="1237"
export GUEST_CONSOLE_PORT="1235"
export GDB_PORT="1234"
export SSH_PORT="8000"
