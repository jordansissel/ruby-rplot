
module RPlot

  class Tick
    attr_accessor :value
    attr_accessor :label
    attr_accessor :depth
    attr_accessor :ticklength
    attr_accessor :tickwidth

    def initialize(value, label)
      @value = value
      @label = label
      @depth = 0
      @ticklength = 3
      @tickwidth = 1
    end

  end

  class Ticker
    attr_reader :step
    attr_reader :alignment

    def initialize(alignment, step)
      @alignment = alignment
      @step = step
    end

    def each(min, max)
      raise "NotImplemented. You must subclass #{self.class}"
    end

    def align(value)
      return value - (value % @alignment)
    end
  end

  class TimeTicker < Ticker
    def initialize(format, alignment=3600, step=3600)
      @format = format
      super(alignment, step)
      @alignment = 1 if @alignment == 0
    end
    
    def each(min, max)
      value = align(min)
      value += @step
      while value <= max
        time = Time.at(value)
        yield Tick.new(value, time.strftime(@format))
        value += @step
      end
    end
  end

  class SmartTimeTicker < TimeTicker
    HOUR = 60 * 60
    DAY = HOUR * 24
    WEEK = DAY * 7
    MONTH = WEEK * 4
    YEAR = WEEK * 52

    # Really, we should automatically figure out the correct alignment
    # and stepping.
    @@distance_map = {
      HOUR => [TimeTicker.new("%H:%M", alignment=60*5, step=60*5)],
      3 * HOUR => [TimeTicker.new("%H:%M", alignment=60*5, step=60*5)],
      12 * HOUR => [TimeTicker.new("%H:%M", alignment=HOUR, step=HOUR*2)],
      36 * HOUR => [TimeTicker.new("%H:%M", alignment=HOUR, step=HOUR*7)],
      3 * DAY => [TimeTicker.new("%b %d", alignment=DAY, step=DAY)],
      7 * DAY => [TimeTicker.new("%A", alignment=HOUR, step=DAY),
                  TimeTicker.new("%b %d", alignment=HOUR, step=DAY)],
      2 * WEEK => [TimeTicker.new("%b %d", alignment=DAY, step=DAY*3)],
      4 * WEEK => [TimeTicker.new("%b %d", alignment=WEEK, step=WEEK)],
      3 * MONTH => [TimeTicker.new("%B", alignment=MONTH, step=MONTH)],
      YEAR => [TimeTicker.new("%b %Y", alignment=MONTH, step=MONTH)],
    }.sort { |a,b| a[0] <=> b[0] }

    def initialize
      super(0, 0)
    end

    def align(value, mod)
      return value - (value % mod)
    end
    
    def each(min, max)
      # compute time distance and automatically pick the
      # smartest format, alignment, and step.
      distance = max - min
      tickerlist = @@distance_map.first[0]
      @@distance_map.each do |key,value|
        tickerlist = value
        break if key > distance
      end


      depth = 0
      tickerlist.each do |ticker|
        puts ticker.inspect
        puts ticker.step / 60 / 60 / 24.0
        count = 0
        ticker.each(min, max) do |tick| 
          tick.depth += depth
          yield(tick)
          count += 1
        end
        puts "#{count} ticks"
        depth += 1
      end
    end
  end

  class StandardTicker < Ticker
    def initialize(alignment, step)
      super(alignment, step)
      @alignment = 1 if @alignment == 0
    end
    
    def each(min, max)
      value = align(min)
      value += @step
      while value <= max
        yield Tick.new(value, "#{value}")
        value += @step
      end
    end
  end
end
