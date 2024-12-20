#!/bin/bash -e

. $(dirname "$0")/config.sh

KERNEL="$KERNEL_BUILD_DIR/arch/x86/boot/bzImage"
if [ ! -f $KERNEL ]; then
	echo "Please make sure the kernel is available as per the configuration"
	exit 1
fi

if [ ! -e initrd ]; then
  echo "
Please create an initrd for the test:

  $ ./mkinitramfs.sh initrd"
  echo 1
fi

set -x

/usr/bin/qemu-system-x86_64 \
	-smp 40 \
	-kernel $KERNEL \
	-initrd $INITRD_PATH \
	-cpu host,vmx=on \
	-machine q35,kernel-irqchip=split \
	-device intel-iommu,intremap=on,device-iotlb=on \
	-enable-kvm \
	-m 192G \
	-drive file=$GUEST_IMAGE,if=none,id=nvme0,format=qcow2,snapshot=on \
	-device nvme,drive=nvme0,serial=1234 \
	-netdev user,id=n0,hostfwd=tcp::5900-:5900,hostfwd=tcp::$SSH_PORT-:$SSH_PORT,hostfwd=tcp::3389-:3389,hostfwd=tcp::$GUEST_CONSOLE_PORT-:$GUEST_CONSOLE_PORT,hostfwd=tcp::$HOST_TELNET_PORT-:$HOST_TELNET_PORT,hostfwd=tcp::$GDB_PORT-:$GDB_PORT \
	-device e1000,netdev=n0 \
	-display none \
	-device virtio-serial-pci \
	-chardev stdio,id=c,signal=off,mux=on \
	-mon chardev=c,mode=readline \
	-device virtconsole,chardev=c \
	-device qemu-xhci \
	-append "console=hvc0 kvm_intel.dump_invalid_vmcs=1 nokaslr vfio_iommu_type1.allow_unsafe_interrupts=1 $1 $2" \
	-virtfs local,path=$SHARE_DIR,mount_tag=host,security_model=none \
