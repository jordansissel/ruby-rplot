#!/usr/bin/env ruby

require "rubygems"
require 'rvg/rvg'


class RPlot
  attr_accessor :width
  attr_accessor :height
  attr_accessor :title
  attr_accessor :axes

  def initialize(width, height, title)
    @title = title
    @axes = []
    @attrs = PlotAttributes.new
    @attrs.width = width
    @attrs.height = height
  end

  def analyze
    @attrs.min_x = @axes[0].points[0][0]
    @attrs.min_y = @axes[0].points[0][1]
    @attrs.max_x = @axes[0].points[0][0]
    @attrs.max_y = @axes[0].points[0][1]

    @axes.each do |axis|
      axis.points.each do |point|
        @attrs.min_x = point[0] if point[0] < @attrs.min_x
        @attrs.min_y = point[1] if point[1] < @attrs.min_y
        @attrs.max_x = point[0] if point[0] > @attrs.max_x
        @attrs.max_y = point[1] if point[1] > @attrs.max_y
      end
    end

    @attrs.grid_y_step = @attrs.distance_y / 5
    @attrs.grid_x_step = @attrs.distance_x / 30
  end

  def render(output)
    analyze

    # Compute min/max x and y
    # If need grid, calculate grid spacing
    # If need axis labels:
    #   calculate spacing for ticks
    rvg = Magick::RVG.new(@attrs.width, @attrs.height) do |canvas|
      canvas.background_fill = 'white'
      plot = render_data
      canvas.use(render_frame)
      canvas.use(plot, 80, 30)

      # Put yticks just left of the graph
      yticks = render_yticks(plot.height)
      xticks = render_xticks(plot.width)
      canvas.use(yticks, 80 - yticks.width, 30)
      canvas.use(xticks, 80, 30 + plot.height)
    end
    rvg.draw.write(output)
  end
 
  def render_frame
    rvg = Magick::RVG.new(@attrs.width, @attrs.height) do |canvas|
      canvas.rect(@attrs.width-1, @attrs.height-1, 0, 0) \
        .styles(:stroke => "grey", :stroke_width => 1, :fill => "white")
      canvas.rect(@attrs.width-3, @attrs.height-3, 1, 1) \
        .styles(:stroke => "black", :stroke_width => 1, :fill => "#E8F8F8")
      canvas.text(@attrs.width / 2, 20, @title) \
        .styles(:text_anchor => "middle",
                :font_size => 16)
    end
    return rvg
  end

  def render_data
    width = @attrs.width - 100
    height = @attrs.height - 60
    rvg = Magick::RVG.new(width, height) do |canvas|
      canvas.rect(width, height, 0, 0) \
        .styles(:stroke => "none", :fill => "white")
      #grid = render_grid
      #canvas.use(grid, 0, 0)

      @axes.each do |axis|
        data = axis.render(width, height, @attrs)
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
    rvg = Magick::RVG.new(width, height) do |canvas|
      #ry = @attrs.distance_y / @attrs.grid_y_step
      y = @attrs.grid_y_step / @attrs.ratio_y(height)
      while (y < height)
        canvas.polyline(0, y, width, y) \
          .styles(:stroke => "#C8CECE", :stroke_width => 1)
        y += @attrs.grid_y_step / @attrs.ratio_y(height)
      end
    end
    return rvg
  end

  def render_yticks(height)
    width = 100 
    height = height
    rvg = Magick::RVG.new(width, height)
    ticker = StandardTicker.new(alignment=0, step=1)
    ticker.each(@attrs.min_y, @attrs.max_y) do |value, label|
      y = @attrs.translate(0, value, 0, height)[1]
      #puts y
      rvg.polyline(width, y, width-5, y) \
        .styles(:stroke => "black", :stroke_width => 1)
      rvg.text(width-10, y, label.to_s) \
        .styles(:text_anchor => "end", :baseline_shift => "100%")
    end
    return rvg
  end

  def render_xticks(width)
    width = width
    height = 30
    rvg = Magick::RVG.new(width, height)
    ticker = TimeTicker.new("%H:%M", alignment=3600, step=60*60*12)
    ticker.each(@attrs.min_x, @attrs.max_x) do |value, label|
      x = @attrs.translate(value, 0, width, 0)[0]
      rvg.polyline(x, 0, x, 5) \
        .styles(:stroke => "black", :stroke_width => 1)
      rvg.text(x, 15, label) \
        .styles(:text_anchor => "middle")
    end
    return rvg
  end
end

class GraphAxis
  attr_accessor :points

  def initialize
    @points = []
  end

  def render(width, height, attrs)
    # we could use 'viewbox' here to make life easy, but that changes what '1'
    # means for stroke width, etc. Also, it doesn't invert the axis.
    #rvg.viewbox(min_x, min_y, (max_x - min_x), (max_y - min_y)) do |canvas|

    # Translate functions to convert a data point to a display point
    #xtrans = lambda { |x| (x - attrs.min_x) / xratio }
    # ytrans should invert, (larger 'y' means higher on the graph)
    #ytrans = lambda { |y| height - ((y - attrs.min_y) / yratio) }

    rvg = Magick::RVG.new(width, height)  do |canvas|
      # Translate all the points, then plot with polyline.
      transpoints = @points.collect { |x,y| attrs.translate(x, y, width, height) }

      # Fill under the curve by making a polygon of the line; prepending
      # the origin and appending the largest viewable X value + y origin
      canvas.polygon(*([[0, height], transpoints, [width, height] ].flatten)) \
        .styles(:stroke => "none", :fill => "#F3F3D9", :fill_opacity => 0.8)

      # Draw the line
      canvas.polyline(*(transpoints.flatten)) \
        .styles(:stroke_width => 1, :stroke => "red", :fill => "none")

      # Use bezier curves? This makes the data draw funnily.
      #p = "M#{transpoints.first[0]},#{transpoints.first[1]} "
      #p += "T" + transpoints.collect { |x,y| "#{x},#{y}"}.join(" ")
      #canvas.path(p).styles(:fill => "none", :stroke => "green")

      # Put a dot at each data point
      transpoints.each do |x,y|
        canvas.circle(1, x, y)
      end
    end
    return rvg
  end
end

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
    return distance_y / val.to_f
  end

  # Translate points x,y into zero-origin view of width x height
  def translate(x, y, width, height)
    tx = (x - @min_x) / ratio_x(width)
    ty = height - (y - @min_y) / ratio_y(height)

    #puts "#{x},#{y} -> #{tx},#{ty}"

    return [tx, ty]
  end
end

# A ticker is a class that provides an iterator
# that should yield tick values via 'each'
class Ticker
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
      yield value, time.strftime(@format)
      value += @step
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
      yield value, "#{value} pants"
      value += @step
    end
  end
end


graph = RPlot.new(400, 200, "Happy Graph")

points = 60
axis = GraphAxis.new
(1..points).each do |i| 
  axis.points << [Time.now.to_f + i*3600, Math.log(i)]
end

axis2 = GraphAxis.new
(1..points).each do |i| 
  axis2.points << [Time.now.to_f + i*3600, Math.sin((i / 2.0).to_f) + 1]
end

graph.axes << axis
graph.axes << axis2

graph.render("/home/jls/public_html/test.gif")
