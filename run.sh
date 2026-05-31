#!/bin/sh

. $(dirname "$0")/config.sh

# Defaults; overridden by /host/dev_env (written by run_tmux.py).
# The env file is sourced only by L1; L2 sees dev_env_l2 in cmdline and
# is dispatched to run_l2.sh before reaching here, but be defensive in
# case run.sh is invoked directly inside L2.
DEV_GDB=0
DEV_TRACE=0
DEV_NESTED=0
DEV_UNIT=
DEV_SELFTEST=
DEV_PAYLOAD=
if ! grep -q dev_env_l2 /proc/cmdline && [ -r /host/dev_env ]; then
	. /host/dev_env
fi

VARS=sb
MACHINE=pc
grep -q blank /proc/cmdline && VARS=blank
grep -q q35 /proc/cmdline && MACHINE=q35

[ "$DEV_GDB" = "1" ] && DBG="gdb --args"
if [ "$DEV_TRACE" = "1" ]; then
	DBG="trace-cmd record -e kvm -e kvmmmu:kvm_faultin_memory_protections -o /host/trace.dat"
fi
TRACE_CMD="--trace \"hyperv_*\" --trace \"kvm_*\""

if [ -n "$DEV_UNIT" ]; then
	CMD="$DBG ./kvm-unit-tests/$DEV_UNIT"
elif [ -n "$DEV_SELFTEST" ]; then
	CMD="$DBG ./host/run_kselftest.sh -t $DEV_SELFTEST; poweroff"
elif [ "$DEV_NESTED" = "1" ]; then
	rm -f /host/payload_result
	CMD="$DBG /host/qemu-system-x86_64"
	CMD="$CMD -smp 4"
	CMD="$CMD -kernel /host/bzImage"
	CMD="$CMD -initrd /host/initrd"
	CMD="$CMD -cpu host,+kvm-guest-hints"
	CMD="$CMD -machine q35"
	CMD="$CMD -enable-kvm"
	CMD="$CMD -m 4G"
	CMD="$CMD -net none"
	CMD="$CMD -display none"
	CMD="$CMD -device virtio-serial-pci"
	CMD="$CMD -chardev stdio,id=c,signal=off,mux=on"
	CMD="$CMD -mon chardev=c,mode=readline"
	CMD="$CMD -device virtconsole,chardev=c"
	CMD="$CMD -append \"console=hvc0 nokaslr dev_env_l2\""
	CMD="$CMD -virtfs local,path=/host,mount_tag=host,security_model=none"
	if [ -n "$DEV_PAYLOAD" ]; then
		CMD="$CMD; cat /host/payload_result 2>/dev/null || echo 'L2: NO RESULT FILE'; poweroff"
	fi
elif [ -n "$DEV_PAYLOAD" ]; then
	rm -f /host/payload_result
	CMD="PAYLOAD_RESULT_FILE=/host/payload_result $DBG /host/payloads/$DEV_PAYLOAD"
	CMD="$CMD; cat /host/payload_result 2>/dev/null || echo 'L1: NO RESULT FILE'; poweroff"
else
	CMD="$DBG qemu-system-x86_64 $TRACE_CMD"
	CMD="$CMD -machine $MACHINE"
	CMD="$CMD -smp $CPUS"
	CMD="$CMD -cpu host,$HV_FLAGS"
	CMD="$CMD -enable-kvm"
	CMD="$CMD -net none"
	CMD="$CMD -m $MEM"
	CMD="$CMD -vnc :0"
	CMD="$CMD -drive file=/dev/nvme0n1,if=none,id=d,cache=none,format=raw"
	CMD="$CMD -device nvme,drive=d,serial=1234,bootindex=1"
	CMD="$CMD -device qemu-xhci -device usb-tablet"
	CMD="$CMD -netdev user,id=nd,hostfwd=tcp:10.0.2.15:3389-:3389,hostfwd=tcp:10.0.2.15:$SSH_PORT-:22"
	CMD="$CMD -device e1000,netdev=nd"
	CMD="$CMD -drive if=pflash,format=raw,unit=0,readonly=on,file=/OVMF_CODE.2018.fd"
	CMD="$CMD -drive if=pflash,format=raw,unit=1,file=/OVMF_VARS.$VARS.fd"
	CMD="$CMD -monitor stdio"
	CMD="$CMD -serial tcp:10.0.2.15:$GUEST_CONSOLE_PORT,server,nowait"
	CMD="$CMD -action panic=none"
fi

echo Running: $CMD
eval "$CMD"
