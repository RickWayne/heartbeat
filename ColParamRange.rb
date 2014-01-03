# $Revision: 1.4 $
# $Log: ColParamRange.rb,v $
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
class ColParamRange
    attr_reader :name, :min, :max
    attr_writer :col
    @@rePatStr = "(<(T|t)(D|d)[^<]*</*(T|t)(D|d)[^>]*>){%d,%d}<(T|t)(D|d)[^>]*>(\\d+.\\d*)"
    @@matchExpIndex = 8
    @@verbose = false
    
    def initialize(nm,cl,mn,mx)
        @name=nm
        @col=cl
        @min=mn
        @max=mx
        @reStr = sprintf(@@rePatStr,@col,@col)
        @re = Regexp.new(@reStr)
    end

    def ColParamRange.verbose=(aNewValue)
        @@verbose = aNewValue
    end
    
    def ColParamRange.rePatStr=(aNewREPatStr)
        @@rePatStr = aNewREPatStr
        if @col != nil
            @re = Regexp.new(@@rePatStr % @col,@col)
        end
    end

    def ColParamRange.matchExpIndex=(aNewIndex)
        @@matchExpIndex = aNewIndex
    end
        
    def getColValue(str)
        @re = Regexp.new(@reStr)
        md = @re.match(str)
        if md != nil
            if md.size > @@matchExpIndex
                if @verbose
                    print "matched #{md.size} items with \n\"#{@reStr}\" in \n\"#{str}\"\n"
                    md.size.times { |ii| print "  match item: \"#{md[ii]}\"\n" }
                end
                return md[@@matchExpIndex].to_f
            else
                print "md.size is #{md.size} and matchExpIndex is #{@@matchExpIndex}\n"
            end
        else
            print "no match to \n\"#{@reStr}\" in \n\"#{str}\"\n"
            return nil
        end
        #if str =~ @re
        #    return $8.to_f
        #end
    end
    
    def isGood(line)
        val = getColValue(line)
        if val == nil
            return false
        end
        # print "isGood: val is #{val}\n"
        if val < @min || val > @max
            return false
        end
        return true
    end # isGood
end # ColParamRange
    
    
    
