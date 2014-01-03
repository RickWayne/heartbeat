# Check SQL database for the desired stuff

require 'rubygems'
require 'bundler/setup'
require 'active_record'

DAY_SECONDS = 24*3600 # Wrong on DST transition days, but won't hurt

class AwonStation < ActiveRecord::Base
  has_many :t411s
  has_many :t412s
  has_many :t403s
end

class T411 < ActiveRecord::Base
  belongs_to :awon_station
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :date; end
end

class T412 < ActiveRecord::Base
  belongs_to :awon_station
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :date; end
end

class T403 < ActiveRecord::Base
  belongs_to :awon_station
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :date; end
end

class Hyd < ActiveRecord::Base
  def self.yesterday_for(aTime=Time.new)
    # before 11 on any given day, look for actual yesterday HYD. after that, today's should be there
    (aTime.hour < 11) ? aTime - DAY_SECONDS : aTime
  end
  def self.date_sym; :date; end
end

class AsosStation < ActiveRecord::Base
  has_many :asos_data
end

class AsosDatum < ActiveRecord::Base
  belongs_to :asos_station
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :date; end
end

class WiMnDAveTAir < ActiveRecord::Base
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :dateStamp; end
end
  
class WiMnDAveVapr < ActiveRecord::Base
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :dateStamp; end
end
  
class WiMnDMaxTAir < ActiveRecord::Base
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :dateStamp; end
end

class WiMnDMinTAir < ActiveRecord::Base
  def self.yesterday_for(aTime=Time.new); aTime - DAY_SECONDS; end
  def self.date_sym; :dateStamp; end
end
  
class SQLChecker
  def initialize(database='uwex_agwx_devel',server='localhost',user='uwex_agwx_devel',pw='agem.Data')
    @database = ActiveRecord::Base.establish_connection(
      adapter: 'postgresql', hostname: server, username: user, password: pw, database: database
    )
  end
  
  def hasYesterday(aClass,aTime=Time.new,condition=nil)
    yesterday = aClass.yesterday_for(aTime)
    result = aClass.where({aClass.date_sym => yesterday})
    condition ? result.where(condition).size > 0 : result.size > 0
  end
  
  # Check that 7 daily records exist backwards from aTime for which condition is true
  def allLastWeek(aClass,condition=nil,aTime=Time.new)
    yesterday = aClass.yesterday_for(aTime)
    lastWeek = yesterday - 6 * DAY_SECONDS
    results = aClass.where({aClass.date_sym => (lastWeek..yesterday)})
    condition ? results.where(condition).size == 7 : results.size == 7
  end
end

