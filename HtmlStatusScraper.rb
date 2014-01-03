#!/usr/bin/env ruby
# HtmlStatusScraper
# $Revision: 1.12 $
# $Log: HtmlStatusScraper.rb,v $
# Revision 1.12  2006/08/16 20:29:06  wayne
# some minor tweaks
#
# Revision 1.11  2005/12/05 15:27:38  wayne
# currently broken, think it was the last changes to webcam stuff
#
# Revision 1.10  2005/09/16 14:19:52  wayne
# Finishing the new-style EMS heartbeat (with logins and everything)
#
# Revision 1.9  2005/08/25 15:10:42  wayne
# dos2unix
#
# Revision 1.8  2004/08/06 18:31:28  wayne
# Added HTML error message buffer
# Removed OPUMKE entirely
# Made EMS checker case-insensitive
#
# Revision 1.7  2004/07/23 16:03:32  wayne
# many updates and fixes; now does HTML output and SQL checking
#
# Revision 1.6  2004/03/02 21:08:44  wayne
# Further refinements
#
# Revision 1.5  2002/07/10 16:13:04  wayne
# Fixed problem with OPU; now won't look for today's OPU until noon. Also made
# @verbose in Html*Scraper an instance variable, and added the grid stuff.
# Modified Files:
# HtmlStatusScraper.rb HtmlTableStatusScraper.rb
# StatusChecker.rb
# Added Files:
# GridStatusChecker.rb grid.rb gridtest.rb
#
# Revision 1.4  2002/07/08 22:56:44  wayne
# Got everything including OPU and OPUMKE going at once (!). Now, on to grids
# and SQL databases directly!
# Modified Files:
# 	ColParamRange.rb HtmlStatusScraper.rb
# 	HtmlTableStatusScraper.rb StatusChecker.rb
#
# Revision 1.3  2002/06/07 16:27:01  wayne
# Now it's AWS, ASOS, and ASOS Degree Days are all working.
#

# Screen-scrape a URL and validate it

# obtain the page
# search for the correct line(s) -- are they there?
# pass those lines into the validator

require 'net/http'

class HtmlStatusScraper
    attr_writer :serverStr
    attr_writer :verbose
    attr_reader :errMesg

    def initialize(url,lineMatch,port=80,verbose=false)
        @serverStr = 'www.soils.wisc.edu'
        @h = Net::HTTP.new(@serverStr,port)
        @urlStr = url
        @lineMatch = lineMatch
        @verbose = verbose
    end

    # if we set the server, we have to create a new "HTTP"
    def serverStr=(aNewServer,port=80)
        @serverStr = aNewServer
        @h = Net::HTTP.new(@serverStr,port)
    end

    # search return for matchStr; do a checkValue on it    
    def validate(absence=false)
        @errMesg = ""
         print "doing the get for \"http://#{@serverStr}#{@urlStr}\"\n" if @verbose
	begin
          resp,@data = @h.get(@urlStr,nil)
          # sometimes we might get a redirect, e.g. Cocoon login
          if resp.code == "302"
                  resp.each {|key,val| printf "%-14s = %-40.40s\n",key,val} if @verbose
                  redirectURLStr = resp["location"]
                  resp,@data = @h.get(redirectURLStr,nil)
          end
          if resp.code == "200"
              if block_given?
                  valuesOK = yield @data
              else
                  @data.each { |line| print "-->#{line}<--" } if @verbose
                  print "HSS validate: scanning for lines that match \"#{@lineMatch.to_s}\"\n" if @verbose
                  if absence then valuesOK=true else valuesOK = nil end
                  @data.scan(Regexp.new(@lineMatch)) do
                      |line|
                      print "validate: line is \"#{line}\"\n" if @verbose
                      if absence
                        return false # the mere presence of a match is enough to kill us!
                      end
                      cv = checkValues(line)
                      print "HSS validate: checkValues returns #{cv} for it\n" if @verbose
                      if valuesOK == nil
                          valuesOK = cv
    		      print "HSS validate: cv is #{cv} and valuesOK is #{valuesOK}\n" if @verbose
                      else
    		      print "HSS validate: cv is #{cv} and valuesOK is #{valuesOK}\n" if @verbose
                          valuesOK &= (valuesOK && cv)
                      end
                  end
                  print "HSS validate: returning #{valuesOK}\n" if @verbose
    	          return valuesOK
              end
          else
              @errMesg = " could not get page \"http://#{@serverStr}#{@urlStr}\"; message was \"#{resp.message}\" and the code was #{resp.code}\n "
              @data.each { |line| print "-->#{line}" } if @verbose
          end
          if valuesOK != nil
              return valuesOK
          else
              return false
          end
	rescue Exception => e
	  @errMesg = "hit an exception for \"http://#{@serverStr}#{@urlStr}\":<br/>#{e.to_s}<br/>#{e.backtrace.join}\n"
	end
    end
    
    # this default implementation is useful when only mere existence
    # of the line is enough to say "bueno"
    def checkValues(line)
        return true
    end

end

# HtmlStatusScraper.new('foo','bar')
#today = Date.today            
#scraper = StatusScraper.new('/servlets/servlet/EDU.wisc.soils.AWSReport.AWSRepServlet',
#                           "<TD>#{today.year.to_s}-0*#{today.mon.to_s}-#{((today.mday)-1).to_s}<\/TD><TD.*>(\d*\.\d*)")
