require 'date'
class LogChecker
  def self.find_in_log(path,regexp)
    (File.open(path,'r').grep(regexp)).size > 0
  end

  def self.find_last_in_log(date_regexp,logname,criterion_regexp)
    results = File.open(logname,'r').grep(criterion_regexp)
    if block_given?
      results = results.sort {|a,b| yield(a,b)}
    else
      results = results.sort
    end
    results[-1] =~ date_regexp
  end
end

# Uncomment to test
# today = Date.today
# yesterday = Date.today - 1
# 
# today_rxp = /^#{today.strftime("%Y-%m-%d")}/
# yesterday_rxp = /^#{yesterday.strftime("%Y-%m-%d")}/
# criterion_rxp = /Successful incremental backup of '\/'/
# puts "Today: yes" if LogChecker.find_last_in_log(today_rxp,'bucky.log',criterion_rxp)
# puts "Yesterday: yes" if LogChecker.find_last_in_log(yesterday_rxp,'bucky.log',criterion_rxp)
# puts "Reverse sort: yes" if LogChecker.find_last_in_log(today_rxp,'bucky.log',criterion_rxp) {|a,b| b <=> a}
