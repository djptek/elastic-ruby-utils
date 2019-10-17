# Create Entity Table in Elastic
# * Extracts aggregations from Elasticsearch
# * Performs calculations on document counts per bucket
# * Maps the calculated data to the summary table
# * Performs a bulk index of the summary table
require "elasticsearch"

module Test_Type
  Field = "test_type.keyword"
  Retest = "RT"
  New_Test = "NT"
end

module Test_Result
  Field = "test_result.keyword"
  Pass = "P"
  Fail = "F"
end

module Index
  Name = "mot_tests"
end 

class Test
  attr_reader :mileage
  attr_reader :age
  attr_reader :id

  def initialize (source)
    @age = source["vehicle_age"].to_f
    @mileage = source["test_mileage"].to_i
    @result = source["test_result"]
    @id = source["vehicle_id"].to_s
    @type = source["test_type"]
  end
end

class Test_Source
  include Index

  Order = "desc"
  attr_reader :Source

  def initialize (id, failed_age, client)
    @search_results = client.search index: Index::Name,
      body: {
        size: 1,
        sort: [ { vehicle_age: { order: Order } } ],
        query: { bool: { filter: [ 
          { term: { vehicle_id: id } },
          { term: { "test_result.keyword" => "P"}},
          { range: { vehicle_age: { gte: failed_age, lte: failed_age+1.0 } } } ]
          } } }
    if @search_results["hits"]["total"] > 0
      @test = Test.new(@search_results["hits"]["hits"][0]["_source"])
    else
      puts "*** write off "+id+" ***"
      @test = nil
    end
  end

  def test
    return @test
  end

end

class Vehicle_History
  attr_reader :miles_driven_with_fail
  attr_reader :days_for_fix

  def initialize (t1, client)
    @t2 = Test_Source.new(t1.id, t1.age, client)
    if @t2.test 
      @miles_driven_with_fail = (t1.mileage - @t2.test.mileage).abs
      @days_for_fix = 365.0*(t1.age - @t2.test.age).abs
    end
  end

  def write_off
    return @t2.test == nil
  end
end

class Source
  include Test_Type
  include Test_Result
  include Index

  Min_Timestamp = "2012-01-01"
  Max_Timestamp = "2013-01-01"
  Max_Size = 1000
 
  def initialize (client)
    @@es_client = client
  end

  def hits
    return @search_results["hits"]["hits"]
  end

  def scroll_id
    return @search_results["_scroll_id"]
  end

  def process_scroll_batch
    puts "Processing Scroll Batch ["+self.scroll_id.to_s+"]"
    target = Target.new(@@es_client)
    self.hits.each { |hit|
      puts hit
      target.add(
        Test.new(hit["_source"]))
    }
    target.bulk_operations @@es_client
  end

  def query
    @search_results = @@es_client.search index: Index::Name,
      scroll: '5m',
      body: {
        sort: ["_doc"],
        size: Max_Size,
        query: { bool: { must: [ 
          { term: { "test_result.keyword" => "F" } },
          { range: { "@timestamp" => { 
             gte: Min_Timestamp, 
             lte: Max_Timestamp } } } ] } } }
    process_scroll_batch

    while @search_results = @@es_client.scroll(
      scroll_id: self.scroll_id, 
      scroll: '5m') and not self.hits.empty? 
      process_scroll_batch
    end
  end

end

class Target
  Index = "miles_with_failure_vs_days_to_fix"
  Id_Suffix = "_retest"
  ES_Type = "doc"
  Miles = "miles_driven_with_fail"
  Days = "days_for_fix"
  Limit = 365

  @@operations = []

  def initialize(client)
    @@es_client = client
  end

  def add (test)
    vehicle = Vehicle_History.new(test, @@es_client)
    @@operations.concat [
      { index: { _index: Target::Index,
        _type: ES_Type,
        _id: test.id+Target::Id_Suffix,
        data: { Miles => vehicle.miles_driven_with_fail,
          Days => vehicle.days_for_fix.round } } } ] unless 
      vehicle.write_off
  end

  def bulk_operations (client)
    client.bulk body: @@operations
  end

end

# MAIN - connect to Elasticsearch
source = Source.new(Elasticsearch::Client.new log: false).query
  

