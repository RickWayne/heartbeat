#!/usr/bin/env ruby

require 'HtmlStatusScraper'
require 'ColParamRange'

class SublinkStatusScraper < HtmlStatusScraper
    def initialize(url,lineMatch,port=80,verbose=false,linkMatch=/wimnext/)
        super(url,lineMatch,port,verbose)
        @linkMatch = linkMatch
    end

    def validate 
      lineMatcher = Regexp.new(@lineMatch)
      super
      got_plots = nil
      @data.each do |line|
        if ((line =~ lineMatcher) != nil)
          if ((line =~ @linkMatch) != nil)
            plot_resp,plot_data = @h.get($&,nil)
            if (got_plots == nil)
              got_plots = (plot_resp.code == "200")
            else
              got_plots &= (plot_resp.code == "200")
            end
          end
        end
      end
      got_plots == nil ? false : got_plots
    end
end

