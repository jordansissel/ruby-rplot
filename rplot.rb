#!/usr/bin/env ruby

require "rubygems"
require 'rvg/rvg'

require "rplot/datasources"
require "rplot/tickers"


module RPlot
  class Graph
    attr_accessor :width
    attr_accessor :height
    attr_accessor :title
    attr_accessor :sources
    attr_accessor :xtickers
    attr_accessor :ytickers

    def initialize(width, height, title)
      @title = title
      @attrs = PlotAttributes.new
      @attrs.width = width
      @attrs.height = height
      @sources = []
      @xtickers = []
      @ytickers = []
    end

    def analyze
      @attrs.min_x = nil
      @attrs.min_y = nil
      @attrs.max_x = nil
      @attrs.max_y = nil

      @sources.each do |source|
        source.each do |point|
          @attrs.min_x = point[0] if (!@attrs.min_x or (point[0] < @attrs.min_x))
          @attrs.min_y = point[1] if (!@attrs.min_y or (point[1] < @attrs.min_y))
          @attrs.max_x = point[0] if (!@attrs.max_x or (point[0] > @attrs.max_x))
          @attrs.max_y = point[1] if (!@attrs.max_y or (point[1] > @attrs.max_y))
        end
      end

      # If we want to expand the viewport, now is the time to do it.
      @attrs.min_y = 0
      #@attrs.max_y += (@attrs.max_y * 0.1)
      @attrs.max_y = 100
    end

    def render(output)
      analyze

      # Compute min/max x and y
      # If need grid, calculate grid spacing
      # If need axis labels:
      #   calculate spacing for ticks
      #rvg.background_fill = 'white'
      plot = render_data

      # Put yticks just left of the graph
      yticks = render_yticks(plot.height)
      xticks = render_xticks(plot.width)

      rvg = Magick::RVG.new(@attrs.width, @attrs.height)
      rvg.use(render_frame)
      rvg.use(plot, 80, 30)
      rvg.use(yticks, 80 - yticks.width, 30)
      rvg.use(xticks, 80, 30 + plot.height)
      image = rvg.draw
      image.write(output)
      #x.format = "png"
      #puts x.to_blob.length
    end
   
    def render_frame
      rvg = Magick::RVG.new(@attrs.width, @attrs.height)
      rvg.rect(@attrs.width-1, @attrs.height-1, 0, 0) \
        .styles(:stroke => "grey", :stroke_width => 1, :fill => "white")
      rvg.rect(@attrs.width-3, @attrs.height-3, 1, 1) \
        .styles(:stroke => "black", :stroke_width => 1, :fill => "#E8F8F8")
      rvg.text(@attrs.width / 2, 20, @title) \
        .styles(:text_anchor => "middle", :font_size => 16)

      xclasses = @xtickers.collect { |t| t.class }
      if xclasses.include?(RPlot::TimeTicker) or xclasses.include?(RPlot::SmartTimeTicker)

        tstart = Time.at(@attrs.min_x).strftime("%Y/%m/%d %H:%M")
        tend= Time.at(@attrs.max_x).strftime("%Y/%m/%d %H:%M")
        rvg.text(@attrs.width - 4, 4, "#{tstart} - #{tend}") \
          .rotate(-90) \
          .styles(:text_anchor => "end", :font_size => 10, :fill => "#333333") \
      end
      return rvg
    end

    def render_data
      width = @attrs.width - 100
      height = @attrs.height - 60
      rvg = Magick::RVG.new(width, height) do |canvas|
        canvas.rect(width, height, 0, 0) \
          .styles(:stroke => "none", :fill => "white")
        grid = render_grid
        canvas.use(grid, 0, 0)

        @sources.each do |source|
          data = source.render(width, height, @attrs)
          canvas.use(data, 0, 0)
        end

        canvas.rect(width, height, 0, 0) \
          .styles(:stroke => "black", :stroke_width => 1, :fill => "none")
      end
      return rvg
    end

    def render_grid
      width = @attrs.width - 100
      height = @attrs.height - 60
      rvg = Magick::RVG.new(width, height)
      @ytickers.each do |ticker|
        ticker.each(@attrs.min_y, @attrs.max_y) do |tick|
          y = @attrs.translate(0, tick.value, 0, height)[1].to_i
          rvg.polyline(0, y, width, y) \
            .styles(:stroke => "#F0F0F0", :stroke_width => 1,
                   :stroke_dasharray => [3, 1])
        end
      end

      @xtickers.each do |ticker|
        ticker.each(@attrs.min_x, @attrs.max_x) do |tick|
          x = @attrs.translate(tick.value, 0, width, height)[0].to_i
          rvg.polyline(x, 0, x, height) \
            .styles(:stroke => "#F0F0F0", :stroke_width => 1,
                   :stroke_dasharray => [3, 1])
        end
      end
      return rvg
    end

    def render_yticks(height)
      width = 100 
      height = height
      rvg = Magick::RVG.new(width, height)
      @ytickers.each do |ticker|
        ticker.each(@attrs.min_y, @attrs.max_y) do |tick|
          y = @attrs.translate(0, tick.value, 0, height)[1].to_i
          rvg.polyline(width, y, width - tick.ticklength, y) \
            .styles(:stroke => "black", :stroke_width => tick.tickwidth)
          if tick.label
            rvg.text(width-10, y, tick.label.to_s) \
              .styles(:text_anchor => "end", :baseline_shift => "100%")
          end
        end
      end
      return rvg
    end

    def render_xticks(width)
      width = width
      height = 30
      rvg = Magick::RVG.new(width, height)
      #ticker = RPlot::TimeTicker.new("%H:%M", alignment=3600, step=60*60*12)
      count = 0
      @xtickers.each do |ticker|
        ticker.each(@attrs.min_x, @attrs.max_x) do |tick|
          x = @attrs.translate(tick.value, 0, width, 0)[0].to_i
          rvg.polyline(x, 0, x, tick.ticklength) \
            .styles(:stroke => "black", :stroke_width => tick.tickwidth)
          if tick.label
            rvg.text(x, 15, tick.label) \
              .styles(:text_anchor => "middle",
                      :baseline_shift => "#{125 * (count + tick.depth)}%")
          end
        end
        count += 1
      end
      return rvg
    end
  end # class Graph
end # module RPlot
 
class PlotAttributes
  attr_accessor :width
  attr_accessor :height
  attr_accessor :min_x
  attr_accessor :min_y
  attr_accessor :max_x
  attr_accessor :max_y
  attr_accessor :grid_y_step
  attr_accessor :grid_x_step

  attr_accessor :tick_x
  attr_accessor :tick_y

  def distance_x
    return @max_x - @min_x
  end

  def distance_y
    return @max_y - @min_y
  end

  def ratio_x(val=@width)
    return distance_x / val.to_f
  end

  def ratio_y(val=@height)
    #return vis_max(distance_y) / val.to_f
    #return 0 if val.to_f == 0
    #return distance_y / Math.log(val.to_f)
    return distance_y / val.to_f
  end

  def vis_min(value)
    return value - (value.abs * 0.1)
  end

  def vis_max(value)
    return value + (value.abs * 0.1)
  end

  # Translate points x,y into zero-origin view of width x height
  def translate(x, y, width, height)
    tx = (x - @min_x) / ratio_x(width)
    ty = height - (y - @min_y) / ratio_y(height)

    #puts "#{x},#{y} -> #{tx},#{ty}"

    return [tx, ty]
  end
end

graph = RPlot::Graph.new(400, 200, "Ping results for www.google.com")

points = 65 
source1 = RPlot::ArrayDataSource.new

start = Time.now.to_f
mul = 60*30

#start = 0
#mul = 1
(1..points).each do |i| 
  source1.points << [start + i * mul, Math.log(i)]
end

source2 = RPlot::ArrayDataSource.new
(1..points).each do |i| 
  source2.points << [start + i * mul, Math.sin((i / 5.0 - 1).to_f) + 1]
end

#graph.sources << source1
#graph.sources << source2

pingsource = RPlot::ArrayDataSource.new
File.open("/b/pingdata").each do |line|
  time,latency = line.split.collect
  pingsource.points << [time.to_f, latency.to_f]
end
pingsource.points = pingsource.points[-300..-1]
graph.sources << pingsource
graph.xtickers << RPlot::SmartTimeTicker.new
graph.ytickers << RPlot::LabeledTicker.new(alignment=0, step=25)
graph.render("/home/jls/public_html/test.png")
