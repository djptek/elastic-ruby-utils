# Create Entity Table in Elastic
# * Extracts aggregations from Elasticsearch
# * Creates geo_shapes
# * Performs a bulk index 
require "elasticsearch"
require "json"
require "gnuplot"

module Source_Index
  Name = "citibike-events-geo"
end 

module Target_Index
  Name = "citibike-trajectories-geo"
end 

class My_Point
  attr_reader :coordinates

  def initialize (source)
    @coordinates = [
        source["station_longitude"].to_f,
        source["station_latitude"].to_f]
    @id = source["bikeid"].to_s
  end
end

class Bike_History
  include Source_Index
  attr_reader :x
  attr_reader :y

  Max_Points = 100
    
  def initialize (bikeid, client)
    @@es_client = client
    #puts "\t for bikeid "+bikeid.to_s
    print "."
    @x = []
    @y = []
    @search_results = @@es_client.search index: Source_Index::Name,
      body: {
        sort: [ timestamp: { "order" => "asc" }],
        size: Max_Points,
        query: { bool: { must: [
          { match: { "bikeid" => bikeid } },
          { match: { "event_type.keyword" => "start" } } ] } },
        _source: ["station_location"] }
    #puts @search_results
    @search_results["hits"]["hits"].each {|hit|
      @x << hit["_source"]["station_location"][0].to_f          
      @y << hit["_source"]["station_location"][1].to_f}          
    # puts @trajectory
  end

end

class Source
  attr_reader :bikeids
  include Source_Index

  Max_Size = 10000

  def initialize (plot)
    @@es_client = Elasticsearch::Client.new log: false
    @@plot = plot
  end

  def query
    @search_results = @@es_client.search index: Source_Index::Name,
         body: {
          size: 0,
          query: { match: { "event_type.keyword" => "start" } },
          aggs: { my_bikeids: { terms: { "field" => "bikeid" , "size" => Max_Size } } } }
    #puts @search_results
    @renderer = Renderer.new(@@es_client, @@plot)
      
    @search_results["aggregations"]["my_bikeids"]["buckets"].each { |bucket|
      #puts "plotting bikeid => "+bucket["key"].to_s
      @renderer.add(bucket["key"])
    }
    
  end

end

class Renderer
  def initialize(client, plot)
    @@es_client = client
    @@plot = plot
  end

  def add (bikeid)
    # puts "\tretrieving history"
    @color = "rgb \"#%06x\"" % rand(0..0xffffff)
    @bike = Bike_History.new(bikeid, @@es_client)
    @@plot.data << Gnuplot::DataSet.new( [@bike.x, @bike.y] ) do |ds|
      ds.with = "lines"
      ds.linewidth = 5
      ds.linecolor = @color
      ds.notitle
    end
  end

end

# MAIN - connect to Elasticsearch
m1 = 111132.92		
m2 = -559.82			
m3 = 1.175			
m4 = -0.0023		
p1 = 111412.84	
p2 = -93.5			
p3 = 0.118			

lat = 40.74*2*Math::PI/360.0
lon = 73.98*2*Math::PI/360.0

# Calculate the length of a degree of latitude and longitude in meters
latlen = m1 + (m2 * Math.cos(2 * lat)) + (m3 * Math.cos(4 * lat)) + (m4 * Math.cos(6 * lat))
longlen = (p1 * Math.cos(lat)) + (p2 * Math.cos(3 * lat)) + (p3 * Math.cos(5 * lat))
@size = "ratio \"%f\"" % (latlen/longlen)

Gnuplot.open do |gp|
  Gnuplot::Plot.new( gp ) {|plot|
    puts @size
    plot.size @size
    #plot.key "outside"
    plot.xlabel "longitude"
    plot.ylabel "latitude"
    plot.terminal "x11  "
      
    plot.title "NY Bike trips rendered using gnuplot see http://www.gnuplot.info/"
   
    source = Source.new(plot).query
  }
end

