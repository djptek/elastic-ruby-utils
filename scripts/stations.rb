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
  Name = "citibike-stations-geo"
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

class Station
  include Source_Index
  attr_reader :fields
  
  def initialize (station_id, client)
    @@es_client = client
    puts "\t for station_id "+station_id
    @fields = {}  
    @search_results = @@es_client.search index: Source_Index::Name,
      body: {
        _source: "station*",
        size: 1,
        query: { 
          match: { "station_id.keyword" => station_id } } }
    puts @search_results
    @search_results["hits"]["hits"].each {|hit|
      @fields = hit["_source"]}          
    # puts @trajectory
  end

end

class Source
  attr_reader :bikeids
  include Source_Index

  Max_Size = 1000

  def initialize (client)
    @@es_client = client
  end

  def query
    @search_results = @@es_client.search index: Source_Index::Name,
         body: {
          size: 0,
          aggs: { stations: { terms: { "field" => "station_id.keyword" , "size" => Max_Size } } } }
    #puts @search_results
    @target = Target.new(@@es_client)
    @search_results["aggregations"]["stations"]["buckets"].each { |bucket|
      puts "adding station_id => "+bucket["key"].to_s
      @target.add(bucket["key"])
    }
    @target.bulk_operations @@es_client
    
  end

end

class Target
  Index = "citibike-stations-geo"
  ES_Type = "_doc"
  
  @@operations = []

  def initialize(client)
    @@es_client = client
  end

  def add (station_id)
    # puts "\tretrieving history"
    @station = Station.new(station_id, @@es_client)
    @@operations.concat [
      { index: { _index: Target::Index,
        _type: Target::ES_Type,
        _id: station_id,
        data: @station.fields } } ]
  end

  def bulk_operations (client)
    # puts @@operations
    client.bulk body: @@operations unless 
      @@operations.length == 0
  end

end

# MAIN - connect to Elasticsearch
source = Source.new(Elasticsearch::Client.new log: false).query
  

