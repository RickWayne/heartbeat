#!/usr/local/bin/ruby -w
  #    The Grid ADT maniputates a very simple ASCII format called a Grid File. Grid files
  #    are designed for data which is easily maintained as a 3D matrix. The following is 
  #    a typical top part of a Grid file:
  #  
  #  7 8 245			[XNo  YNo  ZNo]
  #   -93.000000 -87.000000	[XStart  XEnd]
  #   42.330002 47.000000	[YStart  YEnd]
  #   121 365 1			[ZStart  ZEnd  ZInc]
  #   -99.000000 0		[BadVal  #Decimal_Places]
  #   121			[ZIndex]
  #   8 10 7 4 4 4 4		[Grid Values]		
  #   7 6 6 4 5 4 4
  #   6 8 8 4 4 4 3
  #   7 8 9 6 4 3 3
  #   8 8 8 6 4 3 2
  #   8 8 6 4 4 2 1
  #   6 6 4 2 2 2 2
  #   4 4 2 2 0 2 2
  #   122
  #   19 21 18 14 14 14 13

class GridMetaData
  attr_writer :zDim
  attr_reader :xDim, :yDim, :zDim
  attr_reader :xStart, :xEnd, :xIncr
  attr_reader :yStart, :yEnd, :yIncr
  attr_writer :zStart, :zEnd, :zIncr
  attr_reader :zStart, :zEnd, :zIncr
  attr_writer :badVal
  attr_reader :badVal

  def xDim=(newXDim)
    @xDim = newXDim
    calcXIncr
  end
  def xStart=(newXStart)
    @xStart = newXStart
    calcXIncr
  end
  def xEnd=(newXEnd)
    @xEnd = newXEnd
    calcXIncr
  end

  def calcXIncr
    if @xStart != nil && @xEnd != nil && @xDim != nil then
      @xIncr = (@xEnd - @xStart) / @xDim
    end
  end

  def yDim=(newYDim)
    @yDim = newYDim
    calcYIncr
  end

  def yStart=(newYStart)
    @yStart = newYStart
    calcYIncr
  end

  def yEnd=(newYEnd)
    @yEnd = newYEnd
    calcYIncr
  end

  def calcYIncr
    if @yStart != nil && @yEnd != nil && @yDim != nil then
      @yIncr = (@yEnd - @yStart) / @yDim
    end
  end

  def to_s
    x = "xDim="+@xDim.to_s+",xStart="+@xStart.to_s+",xEnd="+@xEnd.to_s+",xIncr="+xIncr.to_s
    y = "yDim="+@yDim.to_s+",yStart="+@yStart.to_s+",yEnd="+@yEnd.to_s+",yIncr="+yIncr.to_s
    z = "zDim="+@zDim.to_s+",zStart="+@zStart.to_s+",zEnd="+@zEnd.to_s+",zIncr="+zIncr.to_s
    badVal = "badVal="+@badVal.to_s
    x+"\n"+y+"\n"+z+"\n"+badVal
  end

  def initialize(gridFile)
    readMeta(gridFile)
  end

  def readMeta(gridFile)
    @xDim,@yDim,@zDim = gridFile.gets.scan(/\d+/).collect { |s| s.to_f }
    @xStart,@xEnd = gridFile.gets.scan(/-*\d+.\d+/).collect {|s| s.to_f }
    calcXIncr
    @yStart,@yEnd = gridFile.gets.scan(/-*\d+.\d+/).collect {|s| s.to_f }
    calcYIncr
    @zStart,@zEnd,@zIncr = gridFile.gets.scan(/\d+/).collect {|s| s.to_i }
    @badVal = gridFile.gets.scan(/-*\d+.\d+/).collect {|s| s.to_f }
  end
end

class GridLayer
  attr_writer :zIndex
  attr_reader :zIndex
  attr_reader :rows
  def initialize(gridFile,metaData)
    @zIndex = gridFile.gets.scan(/\d+/)[0].to_i
    @rows = Array.new
    for row in 0...metaData.yDim
      @rows[row] = gridFile.gets.scan(/-*\d+.\d+/).collect {|s| s.to_f }
    end
  end
  def to_s
    row0 = @rows[0]
    row0Length = row0.length
    "zIndex: #{@zIndex} num rows: #{@rows.length} num cols: #{row0Length}\n row 0: #{@rows[0]}"
  end
  # return value for x-y posn (x and y in tuple space, not "real" space)
  def get(x,y)
    row = @rows[y]
    if row == nil
        nil
    else
        row[x]
    end
  end
  # compare two layers (based on zIndex)
  def <=>(aLayer)
    if @zIndex < aLayer.zIndex then
        return -1
    elsif @zIndex == aLayer.zIndex then
        return 0
    else
        return 1
    end
  end
end


class Grid
  include Enumerable
  HOURLY=0
  DAILY=1
  attr_reader :period, :xDim, :yDim, :mD

  def initialize(path,period)
    @layers = Array.new
    File.open(path) do |gridFile|
      @mD = GridMetaData.new(gridFile)
      if @mD == nil
        raise "nil metadata"
      end
      @mD.zStart.step(@mD.zEnd,@mD.zIncr) do |layer|
        @layers[layer] = GridLayer.new(gridFile,@mD) unless gridFile.eof
      end
    end
  end
  
  def realToIndex(x,y,z) 
    @myX = ((x-@mD.xStart)/@mD.xIncr).to_i
    @myY = ((y-@mD.yStart)/@mD.yIncr).to_i
    @myZ = ((z-@mD.zStart)/@mD.zIncr).to_i
    # puts "realToIndex: x #{x}, xStart #{@mD.xStart}, xIncr #{@mD.xIncr} myX #{@myX}; y #{y}, myY #{@myY} z #{z}, myZ #{@myZ}"
  end
  
  def get(x,y,z)
    # puts "get #{x},#{y},#{z}"
    # puts "xStart=#{@mD.xStart}, yStart=#{@mD.yStart}, zStart=#{@mD.zStart}"
    # note that this just truncates; it should round to center of cell!
    realToIndex(x,y,z)
    # puts "@myX=#{@myX}, @myY=#{@myY}, @myZ=#{@myZ}"
    # puts "#{@layers[@myZ]}"
    if @layers[@myZ] == nil
        nil
    else
        @layers[@myZ].get(@myX,@myY)
    end
  end

  def each_value(lat,long)
    # note switch here -- grids do longitude as X
    realToIndex(long,lat,0)
    @layers.each do |layer|
        if layer == nil
            yield nil
        else 
            yield layer.get(@myX,@myY)
        end
    end 
  end
  
  def each
    @layers.each { |layer| yield layer }
  end
  
  def toMySQL(connect_str,tableName)
    test = @rows[0]
    test = test.gbsub(/ */,/,/)
    puts "test now: #{test}"
  end
end
#  #!/usr/local/bin/ruby -w
#  load "grid.rb"
#begin # test the Grid class
#    puts "====== initializing a grid =========="
#    grid = Grid.new("WIMNVAvg2002",Grid::DAILY)
#    puts "====== dumping each_value =========="
#    grid.each_value(44.0,-89.0)  {|vapr| puts vapr}
#end

