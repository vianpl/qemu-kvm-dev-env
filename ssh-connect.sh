#!/usr/bin/expect

set host localhost
set port $::env(SSH_PORT)
set timeout 180
set password $::env(SSH_PASSWORD)
set user $::env(SSH_USER)

spawn ssh -o "UserKnownHostsFile=/dev/null" -p $port $user@$host

expect "Are you sure you want to continue connecting (yes/no)?"
send "yes\r"
expect "Administrator@localhost's password:"
send "$password\r"
interact
