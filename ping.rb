
# Really simple replacement for old Ping module. Code from
# http://stackoverflow.com/questions/7519159/ruby-ping-pingecho-missing

require 'timeout'
require 'socket'

class Ping 
  def self.pingecho(host, timeout=5, service="echo")
    begin
      timeout(timeout) do
        s = TCPSocket.new(host, service)
        s.close
      end
    rescue Errno::ECONNREFUSED
      return true
    rescue   Timeout::Error, StandardError 
      return false 
    end
    return true
  end
end