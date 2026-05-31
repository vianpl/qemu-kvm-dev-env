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

# Stage payloads/ so test scripts are reachable from the guest via
# /host/payloads/.
mkdir -p "$SHARE_DIR/payloads"
cp -f "$WORK_DIR"/payloads/* "$SHARE_DIR/payloads/" 2>/dev/null || true
