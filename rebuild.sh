#!/bin/bash

. $(dirname "$0")/config.sh

SELFTEST=
for arg in "$@"; do
	if [ "$arg" = "--selftest" ]; then
		SELFTEST=1
	fi
done

cd $KERNEL_BUILD_DIR
nix-shell -p gcc14 -p elfutils -p openssl  -p gnumake -p ncurses -p glibc -p libtraceevent --command "make -j96"
if [ -n "$SELFTEST" ]; then
	make -C tools/testing/selftests TARGETS=kvm INSTALL_PATH=$SHARE_DIR/ CC=clang -j100 clean
	make -C tools/testing/selftests TARGETS=kvm INSTALL_PATH=$SHARE_DIR/ CC=clang -j100 install
fi
cd -

# Stage bzImage + initrd + patched qemu into the L1->L2 share dir so a
# nested qemu (run.sh with dev_env_nested) can boot the same patched
# kernel as L2 against our patched QEMU. Also stage payloads/ so test
# scripts are reachable from both L1 and L2 via /host/payloads/.
cp "$KERNEL_BUILD_DIR/arch/x86/boot/bzImage" "$SHARE_DIR/bzImage"
cp "$INITRD_PATH" "$SHARE_DIR/initrd"
cp "$QEMU_BUILD_DIR/qemu-system-x86_64" "$SHARE_DIR/qemu-system-x86_64"
mkdir -p "$SHARE_DIR/payloads"
cp -f "$WORK_DIR"/payloads/* "$SHARE_DIR/payloads/" 2>/dev/null || true
