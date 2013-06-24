#!/usr/bin/env ruby

require 'rubygems'
require 'getopt/std'
require 'net/ssh'
require 'unix_crypt'

user="test"
passwd="Password01"

abort "usage:./change_user_passwd.rb [-s] [-t] [-p <userpasswd>] [-f <passwdfile>] <userlogin> [<iplist>]" if ARGV.size < 2

opt = Getopt::Std.getopts("p:f:stl:")

sudo=false
test=false
fixedpass=false
#if opt['u']
#    user=opt['u']
#end
if opt['s']
    sudo=true
    sudoprefix="echo #{passwd}|sudo -S -p \"\" "
end
if opt['f']
    passwdfile=opt['f']
end
if opt['p']
    fixedpass=true
    userpasswd=opt['p']
end
if opt['l']
    passwdlength=opt['l']
else
    passwdlength=12
end
if opt['t']
    test=true
end

username=ARGV[0]
#userpasswd=ARGV[1]
iplist=ARGV[1]

unless fixedpass
    logfile="passwd_#{username}.txt"
    #open <username>_passwd.txt if present copy previous to <username>_passwd-<date>.txt
    system "mv #{logfile} passwd_#{username}-#{Time.now.strftime("%y-%m-%d_%H-%M")}.txt" if File.exists? logfile

    log = File.open(logfile, 'w+')
end

File.open(iplist, 'r').each_line do |l|
    l =~ /^(\S+);((\d+\.){3}\d+)/
    host = $1
    ip = $2
    puts "\e[1;34m[+]\e[00m connecting to #{host}\n"
    begin
        unless fixedpass
            #log all
            userpasswd=rand(36**passwdlength).to_s(36)
        end
        Net::SSH.start(ip, user, :password => passwd) do |ssh|
        salt = rand(36**8).to_s(36)
        hash = "$1$#{salt}$#{UnixCrypt::MD5.hash(userpasswd, salt)}"
        cmd="/usr/sbin/usermod -p '#{hash}' #{username}"
        if sudo
            puts "\e[1;34m[+]\e[00m SUDO:#{cmd}"
            out = ssh.exec!("#{sudoprefix}#{cmd}") unless test
        else
            puts "\e[1;34m[+]\e[00m #{cmd}"
            out = ssh.exec!("#{cmd}") unless test
        end
            puts out if out
        end
        unless fixedpass
            logrecord= "#{host};#{ip};#{username};#{userpasswd}"
            log.puts logrecord 
            puts logrecord
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

