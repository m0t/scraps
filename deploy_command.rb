#!/usr/bin/env ruby

require 'rubygems'
require 'getopt/std'
require 'net/ssh'

user="test"
passwd="Password01"

abort "usage:./deploy_command.rb [-s] [-t] [-u <user>] [-p <passwd>] [-f <passwdfile>] <cmd> [<iplist>]" if ARGV.size < 2

opt = Getopt::Std.getopts("u:p:f:st")

sudo=false
test=false
if opt['s']
    sudo=true
    sudoprefix="echo #{passwd}|sudo -S -p \"\" "
end
if opt['u']
    user=opt['u']
end
if opt['p']
    passwd=opt['p']
end
if opt['f']
    passwdfile=opt['f']
end
if opt['t']
    test=true
end

cmd=ARGV[0]
iplist=ARGV[1]


File.open(iplist, 'r').each_line do |l|
    l =~ /^(\S+);((\d+\.){3}\d+)/
    host = $1
    ip = $2
    puts "\e[1;34m[+]\e[00m connecting to #{host}\n"
    begin
        Net::SSH.start(ip, user, :password => passwd) do |ssh|
        if sudo
            puts "\e[1;34m[+]\e[00m SUDO:#{cmd}"
            out = ssh.exec!("#{sudoprefix}#{cmd}") unless test
        else
            puts "\e[1;34m[+]\e[00m #{cmd}"
            out = ssh.exec!(cmd) unless test
        end
            puts out if out
        end
    rescue Net::SSH::AuthenticationFailed
        $stderr.puts "\e[1;31m[*]\e[00m authentication failed for #{host}\n"
        next
    rescue Net::SSH::HostKeyMismatch
        $stderr.puts "\e[1;31m[*]\e[00m Host key mismatch for #{host}\n"
        next
    rescue Net::SSH::Disconnect
        $stderr.puts "\e[1;31m[*]\e[00m disconnected from #{host}\n"
        next
    rescue Errno::ECONNRESET
        $stderr.puts "\e[1;31m[*]\e[00m connection reset from #{host}\n"
        next
    rescue Errno::EHOSTUNREACH 
        $stderr.puts "\e[1;31m[*]\e[00m No route to host #{host}\n"
        next
    rescue Errno::ETIMEDOUT
        $stderr.puts "\e[1;31m[*]\e[00m connection timeout for #{host}\n"
        next
    rescue Errno::ECONNREFUSED
        $stderr.puts "\e[1;31m[*]\e[00m connection refused for #{host}\n"
        next
    rescue Errno::ENETUNREACH 
        $stderr.puts "\e[1;31m[*]\e[00m unreacheable host #{host}\n"
        next
    end
end

