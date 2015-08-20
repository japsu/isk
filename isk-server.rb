#!/usr/bin/env ruby
# ISK - A web controllable slideshow system
#
# Script for starting and stopping all the various processes
#
# Author::		Vesa-Pekka Palmu
# Copyright:: Copyright (c) 2012-2015 Vesa-Pekka Palmu
# License::		Licensed under GPL v3, see LICENSE.md

require 'mkmf' # We use this to check for external dependecies
require 'colorize'
require "timeout"


WebServer = 'thin'
WebServerPort = 12765
PidDirectory = File.join(File.dirname(__FILE__),'tmp','pids')
Services = [
	:server,
	:resque,
	:background_jobs,
	:rrd_monitoring
]

# Check that all the needed external binaries are present
def check_deps
	unless find_executable 'inkscape'
		abort 'ERROR: ISK needs inkscape to function'.red
	end
	# Get the inkscape version, as the new 0.91 release still has some kinks with bitmaps
	inkscape_version = `inkscape --version`.split[1].split('.')[1].to_i
	if inkscape_version == 91
		puts 'WARNING: Inkscape 0.91 may produce artifacts when scaling bitmaps'.yellow
		unless find_executable('convert') && find_executable('identify')
			abort 'ERROR: ISK needs ImageMagick cmd line utilities (convert and indentify)'.red
		end
	end
end

def start_service(process)
	case process
	when :server
		print 'Starting the web server process...'.ljust(45)
		command = "rails s #{WebServer} -d -p #{WebServerPort} > /dev/null"
	when :resque
		print 'Starting the Resque worker...'.ljust(45)
		command = "TERM_CHILD=1 BACKGROUND=yes PIDFILE=tmp/pids/resque.pid QUEUE=* rake resque:work"
	when :background_jobs
		print 'Starting the timed background jobs worker...'.ljust(45)
		command = "script/background_jobs.rb start > /dev/null"
	when :rrd_monitoring
		print 'Starting the RRD data logger process...'.ljust(45)
		command = "script/rrd_monitoring.rb start > /dev/null"
	else
		abort "ERROR: Unkown process to start: #{process}".red
	end
	if system(command)
		puts 'Success'.green
	else
		puts 'FAILED'.red
		abort
	end
end

def stop_service(process)
	case process
	when :server
		print 'Stopping the web server process'.ljust(45)
		pid_file = 'server.pid'
	when :resque
		print 'Stopping the Resque worker'.ljust(45)
		pid_file = 'resque.pid'
	when :background_jobs
		print 'Stopping the timed background jobs worker'.ljust(45)
		pid_file = 'background_jobs.pid'
	when :rrd_monitoring
		print 'Stopping the RRD data logger process'.ljust(45)
		pid_file = 'rrd_monitoring.pid'
	else
		abort "ERROR: Unknown process to stop: #{process}".red
	end
		
	pid_file = File.join(PidDirectory, pid_file)
	unless File.exists?(pid_file)
		puts 'Not running'.yellow
		return
	end
	pid = File.read(pid_file).to_i
	
	unless !!(`ps -p #{pid}`.match pid.to_s)
		puts 'Not running'.yellow
		return
	end
	
	begin
		Process.kill("TERM", pid)
		Timeout::timeout(20) do
			begin
				print '.'
				$stdout.flush
				sleep 1
			end while !!(`ps -p #{pid}`.match pid.to_s)
		end
		puts 'Success'.green
	rescue Timeout::Error
		puts 'Sending SIGKILL'.yellow
		Process.kill("KILL", pid)
	end
end


case ARGV.first
when 'start'
	check_deps()
	Services.each {|s| start_service(s)}
	exit
when 'stop'
	Services.each {|s| stop_service(s)}
	exit
when 'restart'
	check_deps()
	Services.each {|s| stop_service(s) && start_service(s)}
	exit
else
	puts "Usage isk-server.rb {start|stop|restart}"
	exit 1
end