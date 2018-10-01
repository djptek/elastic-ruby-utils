# Create Entity Table in Elastic
# * Extracts aggregations from Elasticsearch
# * Creates geo_shapes
# * Performs a bulk index 
require "elasticsearch"
require "json"

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
  attr_reader :trajectory
  
  Max_Points = 100
    
  def initialize (bikeid, client)
    @@es_client = client
    puts "\t for bikeid "+bikeid.to_s
    @trajectory = []  
    @search_results = @@es_client.search index: Source_Index::Name,
      body: {
        sort: [ timestamp: { "order" => "asc" }],
        size: Max_Points,
        query: { bool: { must: [
          { match: { "bikeid" => bikeid } },
          { match: { "event_type.keyword" => "start" } } ] } },
        _source: ["station_location"] }
    puts @search_results
    @search_results["hits"]["hits"].each {|hit|
      @trajectory << hit["_source"]["station_location"]}          
    # puts @trajectory
  end

  def write_off
    return @t2.test == nil
  end
end

class Source
  attr_reader :bikeids
  include Source_Index

  Max_Size = 10000

  def initialize (client)
    @@es_client = client
  end

  def query
    @search_results = @@es_client.search index: Source_Index::Name,
         body: {
          size: 0,
          query: { match: { "event_type.keyword" => "start" } },
          aggs: { my_bikeids: { terms: { "field" => "bikeid" , "size" => Max_Size } } } }
    #puts @search_results
    @target = Target.new(@@es_client)
    @search_results["aggregations"]["my_bikeids"]["buckets"].each { |bucket|
      puts "adding bikeid => "+bucket["key"].to_s
      @target.add(bucket["key"])
    }
    @target.bulk_operations @@es_client
    
  end

end

class Target
  Index = "citibike-trajectories-geo"
  ES_Type = "_doc"
  
  @@operations = []

  def initialize(client)
    @@es_client = client
  end

  def add (bikeid)
    # puts "\tretrieving history"
    @bike = Bike_History.new(bikeid, @@es_client)
    @@operations.concat [
      { index: { _index: Target::Index,
        _type: Target::ES_Type,
        _id: bikeid,
        data: { "trajectory_shape" => { 
          "type" => "linestring",
          "coordinates" => @bike.trajectory } } } } ] unless 
      @bike.trajectory.length == 0
  end

  def bulk_operations (client)
    # puts @@operations
    client.bulk body: @@operations unless 
      @@operations.length == 0
  end

end

# MAIN - connect to Elasticsearch
source = Source.new(Elasticsearch::Client.new log: false).query
  

