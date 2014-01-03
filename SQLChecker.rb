#!/usr/bin/env ruby
#
# Check SQL database for the desired stuff
require 'mysql'

class SQLChecker
    def initialize(database='aws',server='molly.soils.wisc.edu',user='soils',pw='soils')
        @database = Mysql.new(server,user,pw,database)
        @results = nil
    end
    
    # utility methods
    def resultHasString(str)
        hasIt = false
        @results.each do |result|
            if ((result[0] <=> str) == 0)
                hasIt = true
            end    
        end
        hasIt
    end
    
    def query(query="show tables")
        @results = @database.query(query)
    end
    
    def hasYesterday(aTime,aTableName,dateColName,condition="")
        if (aTime.nil?)
            aTime = Time.new
        end
        yesterday = Time.at(aTime.to_i - 3600*24)
        yesterYear = yesterday.year
        yesterMonth = yesterday.mon
        yesterMDay = yesterday.mday
        queryDateStr = "%04d-%02d-%02d" % [yesterYear, yesterMonth, yesterMDay]
        query = "select #{dateColName} from #{aTableName} where #{dateColName} >= \'#{queryDateStr}\'"
        if ((condition <=> "") != 0)
            query += "and #{condition}"
        end
        query(query)
        resultHasString(queryDateStr)
    end
    
    def allLastWeek(aTime,recDuration,nRecs,aTableName,dateColName,condition="")
        if (aTime.nil?)
            aTime = Time.new
        end
        yesterday = Time.at(aTime.to_i - recDuration)
        lastWeek = Time.at(yesterday.to_i - recDuration*nRecs)
        yesterYear = yesterday.year
        yesterMonth = yesterday.mon
        yesterMDay = yesterday.mday
        lastWeekYear = lastWeek.year
        lastWeekMonth = lastWeek.mon
        lastWeekMDay = lastWeek.mday
        yesterQueryDateStr = "%04d-%02d-%02d" % [yesterYear, yesterMonth, yesterMDay]
        lastWeekQueryDateStr = "%04d-%02d-%02d" % [lastWeekYear, lastWeekMonth, lastWeekMDay]
        query = "select #{dateColName} from #{aTableName} where #{dateColName} > \'#{lastWeekQueryDateStr}\' and #{dateColName} <= \'#{yesterQueryDateStr}\'"
        if ((condition <=> "") != 0)
            query += "and #{condition}"
        end    
        query(query)
        @results.num_rows == nRecs
    end
end

