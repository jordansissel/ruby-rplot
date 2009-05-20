module RPlot
  class DataSource
    def each
      raise "You mus implement 'each' in your DataSource subclass (#{self.class})"
    end

    def collect
      data = []
      self.each { |x| data << yield(x) }
      return data
    end

    def render(width, height, attrs)
      rvg = Magick::RVG.new(width, height)

      # Translate all the points, then plot with polyline.
      #transpoints = self.collect { |x,y| attrs.translate(x, y, width, height) }
      transpoints = self.collect { |x,y| attrs.translate(x, y, width, height) }
      
      # Fill under the curve by making a polygon of the line; prepending
      # the origin and appending the largest viewable X value + y origin
      rvg.polygon(*([[0, height], transpoints, [width, height] ].flatten)) \
        .styles(:stroke => "none", :fill => "#D9F9D9", :fill_opacity => 0.8)
        
      # Draw the line
      rvg.polyline(*(transpoints.flatten)) \
        .styles(:stroke_width => 1, :stroke => "green", :fill => "none")
        
      # Use bezier curves? This makes the data draw funnily.
      #p = "M#{transpoints.first[0]},#{transpoints.first[1]} "
      #p += "T" + transpoints.collect { |x,y| "#{x},#{y}"}.join(" ")
      #rvg.path(p).styles(:fill => "none", :stroke => "green")

      # Put a dot at each data point
      #transpoints.each do |x,y|
        #rvg.circle(1, x, y)
      #end

      return rvg
    end
  end # class DataSource

  class ArrayDataSource < DataSource
    attr_accessor :points
    def initialize
      @points = []
    end

    def each(&block)
      #@points.each { |p| yield p }
      @points.each(&block)
    end
  end

end
