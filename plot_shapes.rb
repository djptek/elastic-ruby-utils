# Create Entity Table in Elastic
# * Extracts aggregations from Elasticsearch
# * Creates geo_shapes
# * Performs a bulk index 
require "elasticsearch"
require "json"
require "gnuplot"

module Source_Index
  Name = "geo_lab*"
end 

class Geo_Shape
  attr_reader :x
  attr_reader :y

  Max_Points = 100
    
  def initialize (id, my_shape, plot)
    @color = "rgb \"#%06x\"" % rand(0..0xffffff)
    if my_shape["type"] == "point"
      plot.data << Gnuplot::DataSet.new( [[my_shape["coordinates"][0]], [my_shape["coordinates"][1]]] ) do |ds|
        #ds.with = "points pointtype 7 pointsize 3"
        ds.with = "points pointtype 7 pointsize 1"
        ds.title = id
        ds.linecolor = @color
      end
    elsif my_shape["type"] == "linestring"
      @x = []
      @y = []
      my_shape["coordinates"].each {|pair|
        @x << pair[0]
        @y << pair[1]
      }
      plot.data << Gnuplot::DataSet.new( [@x, @y] ) do |ds|
        ds.with = "lines"
        ds.linewidth = 5
        ds.title = id
        ds.linecolor = @color
      end
   elsif my_shape["type"] == "polygon"
      @color = "rgb \"#%06x\"" % rand(0..0xffffff)
      my_shape["coordinates"].each_with_index {|sub_poly, index|
        @x = []
        @y = []
        sub_poly.each {|pair|
          @x << pair[0]
          @y << pair[1]
        }
        plot.data << Gnuplot::DataSet.new( [@x, @y] ) do |ds|
          ds.with = "lines"
          ds.linewidth = 5
          ds.linecolor = @color
          if index == 0 
            ds.title = id
          else
            ds.notitle
          end
        end
      }
    elsif my_shape["type"] == "circle"
      @x = my_shape["coordinates"][0]
      @y = my_shape["coordinates"][1]
      @vertices = 47
      @approx_x_radius = my_shape["radius"].to_f * Math::cos(2*Math::PI*@y/360.0) / 111111
      @approx_y_radius = my_shape["radius"].to_f / 111111
      @polygon_x = []
      @polygon_y = []
        
      (0..@vertices).each {|vertice| 
          @polygon_x << @x + Math::cos(2*Math::PI*vertice/@vertices) * @approx_x_radius
          @polygon_y << @y + Math::sin(2*Math::PI*vertice/@vertices) * @approx_y_radius
          }
      #puts @polygon_x.to_s
      #puts @polygon_y.to_s
      plot.data << Gnuplot::DataSet.new( [@polygon_x, @polygon_y] ) do |ds|
        ds.with = "lines"
        ds.linewidth = 5
        ds.title = id
        ds.linecolor = @color
      end
    else
        puts "type "+my_shape["type"].to_s+" not yet implemented"
    end
  end

end

class Source
  include Source_Index

  Max_Size = 10000

  def initialize (plot)
    @@es_client = Elasticsearch::Client.new log: false
    @@plot = plot
  end

  def query
    @search_results = @@es_client.search index: Source_Index::Name,
         body: {
          size: Max_Size,
          query: { match_all: {} } }
    #@renderer = Renderer.new(@@es_client, @@plot)
      
    @search_results["hits"]["hits"].each { |hit|
      puts "plotting shape => "+hit["_id"].to_s+" "+hit["_source"]["my_shape"].to_s  
      @shape = Geo_Shape.new(hit["_id"].sub("geo_shape_GeoJSON_",""),hit["_source"]["my_shape"], @@plot)
    }
    
  end

end

# MAIN - connect to Elasticsearch
Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) { |plot| 
    plot.size "square"
    plot.key "outside"
    plot.xlabel "longitude"
    plot.ylabel "latitude"
    plot.terminal "x11  "
      
    plot.title "Elasticsearch geo shapes rendered using gnuplot see http://www.gnuplot.info/"
    source = Source.new(plot).query
  }
end

