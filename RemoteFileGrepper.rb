class RemoteFileGrepper
  def RemoteFileGrepper.check(system,path,regexp,return_line=false)
    cmd = %Q[ssh #{system} "grep '#{regexp}' #{path}"]
    # print "#{cmd}\n"
    lines = IO.popen(cmd).read
    # print lines.size unless lines == nil
    unless lines == nil
      if lines.size > 0
        if lines =~ Regexp.new(regexp)
          if return_line then return line else return true end
        end
      end
    end
    return false
  end
end

# print RemoteFileGrepper.check('asig@andi.soils.wisc.edu','/home/asig/products/db/awon_data_archive/data/Arl2007406.csv','^406,4781,7201,')
