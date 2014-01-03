#!/usr/local/bin/ruby -w
load "grid.rb"
#begin # test the Grid class
  # pat = "db/WI_hourly/wx/hvapr200109[0-9]"
  pat = "db/WI_hourly/wx/hvapr2001096"
  Dir.glob(pat).sort.each do |f|
    grid = Grid.new(f,Grid::HOURLY)
    puts(grid.get(-88.5,45.0,22))
    grid.toMySQL("nothing","nothing")
  end
#end
