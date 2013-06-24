#!/usr/bin/env ruby

#by m0t, for his use only,
#you use it and accidentally cause damage, i will not care and laugh a lot, lol

require 'rubygems'
require 'net/ssh'
require 'unix_crypt'
require 'getopt/std'

user="test"
passwd="Password01"

username="user"
logingroup="wheel"
othergroups="users"
uid="3389"
comment=""
home="/home/#{username}"

#example line: 
#user: 11111: i'm a comment: blablabla: blabla: blabla: group:
def parse_list(user, listfile)
    #match only first found line, there should be no duplicates; also, case insensitive SHOULD be ok.
    line=File.readlines(listfile).select { |line| line =~ /#{user}/i }[0]
    val=line.split(':')
    return val[6].strip, val[1], val[2].strip, home 
end

######MAIN#######
abort "usage:./create_linux_user.rb [-p <password>] [-L <userlist>] [-U <username>] [-l <passwdlength>]  [<iplist>]" if ARGV.size < 1

opt = Getopt::Std.getopts("U:L:l:p:")

fixedpass=false
if opt['p']
    fixedpass=true
    userpasswd=opt['p']
end
if opt['U']
    username = opt['U']
end
#requires -U, search named user in list, parse other details, list MUST be in usual ibm format
if opt['L']
    abort "FATAL: -L switch requires -U <username>" unless opt['U']
    logingroup, uid, comment, home = parse_list(username, opt['L'])
end
if opt['l']
    passwdlength=opt['l']
else
    passwdlength=12
end

iplist=ARGV[0]

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
        salt = rand(36**8).to_s(36)
        hash = "$1$#{salt}$#{UnixCrypt::MD5.hash(userpasswd, salt)}"
        #$stderr.puts hash

        Net::SSH.start(ip, user, :password => passwd) do |ssh|
            cmd = "echo #{passwd} |sudo -p \"\" -S /usr/sbin/useradd -u #{uid} -g #{logingroup} -G #{othergroups} -s /bin/bash -d #{home} -c \"#{comment}\" -p '#{hash}' #{username}"
            out = ssh.exec!(cmd)
            #output is not expected nor desired
            unless out =~ /.*exists.*|.*esiste.*/
                $stderr.puts out if out
                out = ssh.exec!("echo #{passwd} |sudo -p \"\" -S chage -d0 #{username}")
                $stderr.puts out if out
                unless fixedpass
                    logrecord= "#{host};#{ip};#{username};#{userpasswd}"
                    log.puts logrecord 
                    puts logrecord
                else
                    puts "\e[1;31m[*]\e[00m user #{username} added to host #{host} with given password"
                end
            else
                $stderr.puts "\e[1;31m[*]\e[00m user already present on host #{host}"
            end
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
