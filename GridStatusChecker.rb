#!/usr/bin/env ruby
require "grid.rb"

now = Time.now
year = now.year
doy = now.yday
prevdoy = doy - 1
hr = now.hour
prevhr = hr - 1

print("time now: #{year} #{doy} #{hr} looking for daily #{year} #{prevdoy}\n")
print("and hourly will be #{year} #{doy} #{prevhr}\n")

# hGrid = Grid.new("db/WI_hourly/wx/hvapr2001096",Grid::HOURLY)
# print("latest layer is #{hGrid.mD.zEnd}\n")
# dGrid = Grid.new("db/asos/WIMNTAvg2002",Grid::DAILY)
# print("latest layer is #{dGrid.mD.zEnd}\n")
