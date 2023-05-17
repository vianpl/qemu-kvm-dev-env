#!/usr/bin/expect

set host localhost
set port $env(HOST_TELNET_PORT)

spawn telnet $host $port

expect "(none) login:"
send "root\r"

interact
