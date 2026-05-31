#!/bin/sh
# Test payload: drive the LOW_LATENCY_VCPU hint via cgroup v2 isolated
# cpuset partitions. Verifies that creating a partition with
# cpuset.cpus.partition=isolated causes the kernel to issue the hypercall
# with the right bitmap, and that removing the partition clears it.
#
# Watch L2's stdout for "kvm: guest hint LOW_LATENCY_VCPU ..." lines from
# QEMU; this payload only sanity-checks what the cgroup interface accepts.

RESULT=${PAYLOAD_RESULT_FILE:-/host/payload_result}

tests_run=0
tests_failed=0

ok() {
	tests_run=$((tests_run + 1))
	echo "ok $tests_run - $1"
}

not_ok() {
	tests_run=$((tests_run + 1))
	tests_failed=$((tests_failed + 1))
	echo "not ok $tests_run - $1 # $2"
}

finish() {
	if [ "$tests_failed" -eq 0 ]; then
		echo "PASS ($tests_run/$tests_run)" > "$RESULT"
	else
		echo "FAIL ($tests_failed/$tests_run failed)" > "$RESULT"
	fi
	echo "1..$tests_run"
	exit "$tests_failed"
}

echo "TAP version 13"

# Mount cgroup v2.
mkdir -p /sys/fs/cgroup
err=$(mount -t cgroup2 none /sys/fs/cgroup 2>&1)
if [ ! -e /sys/fs/cgroup/cgroup.controllers ]; then
	not_ok "cgroup v2 mounted" "mount err: '$err' (cgroup.controllers not present)"
	finish
fi
ok "cgroup v2 mounted"

# Enable cpuset controller in the root cgroup.
if ! grep -qw cpuset /sys/fs/cgroup/cgroup.controllers; then
	not_ok "cpuset controller available" \
		"cpuset not in root controllers: $(cat /sys/fs/cgroup/cgroup.controllers)"
	finish
fi
ok "cpuset controller available"

echo "+cpuset" > /sys/fs/cgroup/cgroup.subtree_control 2>/dev/null
if ! grep -qw cpuset /sys/fs/cgroup/cgroup.subtree_control; then
	not_ok "cpuset enabled in subtree_control" "$(cat /sys/fs/cgroup/cgroup.subtree_control)"
	finish
fi
ok "cpuset enabled in subtree_control"

# Create an isolated partition holding CPUs 1,3.
mkdir -p /sys/fs/cgroup/iso
echo 1,3 > /sys/fs/cgroup/iso/cpuset.cpus
if [ "$(cat /sys/fs/cgroup/iso/cpuset.cpus)" != "1,3" ]; then
	not_ok "set cpuset.cpus=1,3" "$(cat /sys/fs/cgroup/iso/cpuset.cpus)"
	finish
fi
ok "set cpuset.cpus=1,3"

echo isolated > /sys/fs/cgroup/iso/cpuset.cpus.partition 2>/dev/null
state=$(cat /sys/fs/cgroup/iso/cpuset.cpus.partition)
case "$state" in
	isolated)
		ok "partition transitioned to isolated"
		;;
	*)
		not_ok "partition transitioned to isolated" "got '$state'"
		finish
		;;
esac

# The root's cpuset.cpus.isolated reflects the system-wide isolated set.
isolated=$(cat /sys/fs/cgroup/cpuset.cpus.isolated)
if [ "$isolated" = "1,3" ]; then
	ok "system isolated set is 1,3"
else
	not_ok "system isolated set is 1,3" "got '$isolated'"
fi

# Tear down: removing the partition should clear the isolated set, which
# should cause the kernel to fire another hint with an empty bitmap.
echo member > /sys/fs/cgroup/iso/cpuset.cpus.partition
isolated=$(cat /sys/fs/cgroup/cpuset.cpus.isolated)
if [ -z "$isolated" ]; then
	ok "system isolated set cleared after teardown"
else
	not_ok "system isolated set cleared after teardown" "got '$isolated'"
fi

rmdir /sys/fs/cgroup/iso 2>/dev/null

finish
