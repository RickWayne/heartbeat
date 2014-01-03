#!/usr/bin/env ruby
require 'net/http'
require 'date'

def last_months_geopdfs         
  now = DateTime.now
  now -= (now.mday + 1)
  h = Net::HTTP.new('gis.soils.wisc.edu',80)
  resp,data = h.get("/usage/usage_#{now.strftime("%Y%m")}.html")
  lines = ""          
  table_line_index = 0
  in_top_urls_table = false
  data.each do |line|
    if in_top_urls_table
      lines << line
      if line =~ /\/TABLE/
        break
      end
    else
      if line =~ /A NAME="TOPURLS"/
        in_top_urls_table = true
      end
    end
  end

  lines = lines.split "\n"
  lnum=0
  found = false
  lines.each do |line|
    if line =~ /Total GeoPDF/
      found = true
      break
    end
    lnum += 1
  end

  if found
    line = lines[lnum-4]
    line =~ /([\d]+)[^\d]+$/
    return $1.to_i
  end
  return nil
end

# puts last_months_geopdfs