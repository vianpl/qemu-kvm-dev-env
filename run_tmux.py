#!/usr/bin/env python

import argparse
import libtmux
import logging
import subprocess
import sys
import textwrap

log = logging.getLogger()


class ArgsBase:
    date_formats = (
        '%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y',
        '%Y-%b-%d', '%d/%b/%Y', '%d-%b-%Y'
    )

    def __init__(self, description='', epilog=''):
        self.parser = self.__parser(description, epilog)
        self.parsed_args = vars(self.parser.parse_args())
        for key, val in self.parsed_args.items():
            if hasattr(self, key):
                raise AttributeError("Refusing to override attribute %s" % key)
            setattr(self, key, val)

    def __parser(self, description, epilog):
        parser = argparse.ArgumentParser(
            formatter_class=argparse.RawDescriptionHelpFormatter,
            description=textwrap.dedent(description),
            epilog=textwrap.dedent(epilog)
        )

        self._add_arguments(parser)
        return parser

    def _add_arguments(self, parser):
        raise NotImplementedError("Child class should implement this method")

    def dump(self):
        log.info("Called with the following options:")
        for key, val in self.parsed_args.items():
            log.info('%s = %s', key, val)

    def validate(self):
        raise NotImplementedError("Child class should implement this method")


class Args(ArgsBase):
    def __init__(self):
        description = '''
           Use this script to create tmux panes with different components used
           in the emulated environment (i.e. guest console, qemu monitor,
           host shell, etc...).
        '''

        epilog = '''
            Intended Layout:
            #
            # +-----------------------+
            # |           |           |
            # | QEMU      | Guest     |
            # | monitor   | Console   |
            # |           |           |
            # +-----------+-----------+
            # |           |           |
            # | Host      | Guest     |
            # | Shell     | Shell     |
            # |           |           |
            # +-----------+-----------+


            You can run the script the following way and it will create a new
            tmux window with all required panes.

            $ ./scripts/run_tmux.py \\
              --session foo \\
              --gdb \\
              --trace \\
              --unit \\

            If you want run a new window in the current session then you canuse
            use:

            $ ./scripts/run_tmux.py
        '''
        super().__init__(description, epilog)

    def _add_arguments(self, parser):
        parser.add_argument(
            '--session',
            '-s',
            dest='session',
            required=False,
            default=None,
            help='Tmux session id (default: current active tmux session)'
        )

        parser.add_argument('--gdb', action='store_true')
        parser.set_defaults(gdb=False)
        parser.add_argument('--trace', action='store_true')
        parser.set_defaults(trace=False)
        parser.add_argument('--unit', dest='unit', required=False, default=None)

    def validate(self):
        if not self.session:
            try:
                self.session = subprocess.check_output(['tmux', 'display-message', '-p', '#S'])
                self.session = self.session.decode("utf-8").strip()
            except subprocess.CalledProcessError as e:
                log.error("No active session found %d" % e.returncode)
                sys.exit(1)


class Tmux:
    def __init__(self, session, gdb, trace, unit):
        self.tmux_server = libtmux.Server()
        self.session = self.tmux_server.find_where({"session_name": session})
        self.gdb = gdb
        self.trace = trace
        self.unit = unit
        if not self.session:
            raise Exception("No tmux session found with name %s" % session)

    def run(self):
        qemu = self.session.new_window(attach=True, window_name="QEMU/KVM dev env")
        cmd = "./qemu.sh"
        if (self.gdb):
            cmd += " dev_env_gdb"
        if (self.trace):
            cmd += " dev_env_trace"
        if (self.unit):
            cmd += " dev_env_unit={}".format(self.unit)
        cmd += "; read"
        qemu.attached_pane.send_keys(cmd)

        host_shell = qemu.split_window(attach=False)
        host_shell.send_keys('source ./config.sh && sleep 1 && ./telnet-connect.sh; read')

        guest_console = qemu.split_window(attach=False, vertical=False)
        guest_console.send_keys('sleep 2 && nc localhost 1235; read')

        ssh = host_shell.split_window(attach=False, vertical=False)
        ssh.send_keys('source ./config.sh && ./ssh-connect.sh; read')

        host_shell.select_pane()


if __name__ == '__main__':
    args = Args()
    args.validate()

    proc = subprocess.run("grep -n '\[localhost\]:8000' ~/.ssh/known_hosts | cut -d \":\" -f 1", shell=True, capture_output=True)
    if (proc.stdout):
        print("Please delete line starting with [localhost]:8000 in ~/.ssh/known_hosts:{}".format(proc.stdout.decode("utf-8")))
        exit(0)

    proc = subprocess.run("./mkinitramfs.sh initrd", shell=True, capture_output=True)
    if (proc.returncode):
        print("Failed to create initrd:\n{}".format(proc.stderr.decode("utf-8")))
        exit(0)

    try:
        tmux = Tmux(args.session, args.gdb, args.trace, args.unit)
        tmux.run()
    except Exception:
        log.exception("Exception occured")
