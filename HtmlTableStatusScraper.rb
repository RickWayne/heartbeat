#!/usr/bin/env ruby

require 'HtmlStatusScraper'
require 'ColParamRange'

class HtmlTableStatusScraper < HtmlStatusScraper
    attr_writer :colsToCheck
    
    def checkValues(line)
        # print "HtmlTableStatusScraper::checkValues\n"
        valuesOK = true;
        @colsToCheck.each do
            |colChecker|
            colCheck = colChecker.isGood(line)
            good = colCheck ? "good" : "bad"
            print "#{colChecker.name}: #{good}\n" if @verbose
            valuesOK &= colCheck
        end
        return valuesOK
    end
end # class
