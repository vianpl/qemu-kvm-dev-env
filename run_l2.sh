#!/bin/sh
# L2 entry point. Selected by run_dispatch.sh when 'dev_env_l2' is in
# the kernel cmdline.
#
# - If DEV_PAYLOAD is set in /host/dev_env, run that payload and poweroff.
# - Otherwise, just exit so inittab respawns an interactive shell.

DEV_PAYLOAD=
[ -r /host/dev_env ] && . /host/dev_env

if [ -n "$DEV_PAYLOAD" ]; then
	if [ ! -x "/host/payloads/$DEV_PAYLOAD" ]; then
		echo "L2: payload not found: /host/payloads/$DEV_PAYLOAD"
		echo "L2: NO PAYLOAD" > /host/payload_result
		poweroff -f
		exit 1
	fi
	PAYLOAD_RESULT_FILE=/host/payload_result \
		"/host/payloads/$DEV_PAYLOAD"
	poweroff -f
fi

# No payload: fall through; inittab will spawn an interactive shell.
exit 0
