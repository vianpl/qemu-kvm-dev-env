#!/bin/sh

. $(dirname "$0")/config.sh

HV="hv-crash=on"
HV="$HV,hv-vpindex=on"
HV="$HV,hv-relaxed=on"
HV="$HV,hv-synic=on"
HV="$HV,hv-stimer=on"
HV="$HV,hv-runtime=on"
HV="$HV,hv-time=on"
HV="$HV,hv-reset=on"
HV="$HV,hv-time=on"
HV="$HV,hv-xmm-input=on"
HV="$HV,hv-tlbflush-ext=on"
#HV="$HV,hv-xmm-output=on"
HV="$HV,hv-tlbflush=on"
HV="$HV,hv-ipi=on"
HV="$HV,hv-frequencies=on"
HV="$HV,hv-vapic=on"
HV="$HV,hv-stimer-direct=on"
#HV="$HV,hv-vsm=on"
#HV="hv-passthrough=on"

VARS=sb
MACHINE=pc
grep -q blank /proc/cmdline && VARS=blank
grep -q q35 /proc/cmdline && MACHINE=q35
grep -q dev_env_gdb /proc/cmdline && DBG="gdb --args"
grep -q dev_env_trace /proc/cmdline && DBG="trace-cmd record -e kvm -e kvmmmu:kvm_mem_attributes_faultin_access_prots -o /host/trace.dat" && TRACE_CMD="--trace \"hyperv_*\" --trace \"kvm_*\""
grep -q dev_env_unit /proc/cmdline && UNIT=$(cat /proc/cmdline |  sed -n "s/.*dev_env_unit=\([^[:space:],]*\).*/\1/p")

TRACE_CMD="--trace \"hyperv_*\" --trace \"kvm_*\""

if [[ "$UNIT" ]]; then
	CMD="$DBG ./kvm-unit-tests/$UNIT"
else
	CMD="$DBG qemu-system-x86_64 $TRACE_CMD"
	CMD="$CMD -machine $MACHINE"
	CMD="$CMD -smp $CPUS"
	CMD="$CMD -cpu host,$HV"
	CMD="$CMD -enable-kvm"
	CMD="$CMD -net none"
	CMD="$CMD -m $MEM"
	CMD="$CMD -vnc :0"
	CMD="$CMD -drive file=/dev/nvme0n1,if=none,id=d,cache=none,format=raw"
	CMD="$CMD -device nvme,drive=d,serial=1234,bootindex=1"
	CMD="$CMD -device qemu-xhci -device usb-tablet"
	CMD="$CMD -netdev bridge,br=br0,id=net0,helper=/bin/qemu-bridge-helper"
	CMD="$CMD -device e1000,netdev=net0,mac=52:54:00:12:34:57"
	CMD="$CMD -drive if=pflash,format=raw,unit=0,readonly=on,file=./OVMF_CODE.2018.fd"
	CMD="$CMD -drive if=pflash,format=raw,unit=1,file=./OVMF_VARS.$VARS.fd"
	CMD="$CMD -monitor stdio"
	CMD="$CMD -action panic=none"
fi

echo Running: $CMD
eval "$CMD"
