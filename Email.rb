#!/usr/bin/env ruby
# Email.rb
# Handle email parts of heartbeat
require 'net/pop'
require 'net/smtp'
require 'rubygems'
require 'bundler/setup'
require 'mailfactory'

class EmailHeaderChecker
    attr_reader :found
    attr_writer :verbose
    
    def initialize(server,account='fewayne',pw='Schn0krd',verbosity=false)
        @found = false
        @verbose = verbosity
        print("starting...\n") if @verbose
        Net::POP3.start( server,110,account,pw ) do |pop|
          if pop.mails.empty? then
            puts 'no mail.'
          else
            print("#{pop.mails.size} messages\n") if @verbose
            hdrNum=0
            @hdrs = pop.mails.collect { |m|
                if @verbose && hdrNum % 300 == 0
                    print(".")
                end
                hdrNum += 1
                m.header
            }
            print("got headers\n") if @verbose
          end
        end
    end

    # search email headers for a matching line. if we wanted to get really
    # fancy, we could also search the content    
    def find(scanREStr)
        @found = false
        print("starting...\n") if @verbose
        scanRE = Regexp.new(scanREStr)
        @hdrs.each do |hdr|
            if @verbose
                print(" --- new header --- \n")
                print(hdr)
                print(" ------------------ \n")
                end
            if hdr.index(scanRE)
                @found = true
                break;
            end
        end
        @found
    end
    
    def EmailHeaderChecker.test
        tm = Time.now
        print("Start time: #{tm}\n")
        ehc = EmailHeaderChecker.new('facstaff.wisc.edu','fewayne', 'Schn0krd', true)
        print("find returns: #{ehc.find("Subject:\s*ET for #{(tm.year).to_s} #{(tm.yday-1).to_s} at 43.5 -89.25")}\n")
        tm = Time.now
        print("Stop time: #{tm}\n")
    end
end

def sendAlert(alertStr)
    mail = MailFactory.new()
    mail.to = "fewayne@wisc.edu"
    mail.from = "asig@www.soils.wisc.edu"
    mail.subject = "Status check (heartbeat)"
    mail.body = alertStr
    Net::SMTP.start('localhost',25) do |smtp|
	# smtp.send_message mail.to_s, 'asig@www.soils.wisc.edu','6083341928@txt.att.net'
	smtp.send_message mail.to_s, 'asig@www.soils.wisc.edu','fewayne@wisc.edu'
    end
	
    
#   `echo 'Content-type: text/html\n#{alertStr}' | mail -s 'skipped a heartbeat!' fewayne@wisc.edu`
#   `echo 'Content-type: text/html\n#{alertStr}' | mail -s 'ASIG Heartbeat Checker' wlbland@wisc.edu`
end

