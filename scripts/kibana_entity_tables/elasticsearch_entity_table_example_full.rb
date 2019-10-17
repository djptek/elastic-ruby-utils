# Create Entity Table in Elastic
# * Extracts aggregations from Elasticsearch
# * Performs calculations on document counts per bucket
# * Maps the calculated data to the summary table
# * Performs a bulk index of the summary table

require 'elasticsearch'

class Test_Mileage
  Histogram = 'histogram_agg_name'
  Field = 'test_mileage'
  Interval = 10000
end

class Test_Result < Test_Mileage
  Terms = 'terms_agg_name'
  Field = 'test_result.keyword'
  Pass = 'P'
  Fail = 'F'
  Scope = [ Pass, Fail ]
end

class Source < Test_Result
  Index = 'mot_tests'

  # query elastic to aggregate pass/fail to buckets in steps of 10K mileage
  def query (client)
    @search_results = client.search index: Source::Index,
      body: { query: { terms: { Test_Result::Field => Test_Result::Scope } },
        aggs: { Test_Mileage::Histogram => {
          histogram: { field: Test_Mileage::Field,
            interval: Test_Mileage::Interval },
          aggs: { Test_Result::Terms => { terms: { field: Test_Result::Field,
            size: 2 } } } } } }
  end

  def buckets
    return @search_results['aggregations'][Test_Mileage::Histogram]['buckets']
  end

end 

class Bucket < Test_Result

  def initialize (bucket)
    @interval = bucket['key']
    @total = bucket['doc_count'].to_i
    @pass_fail_rates = {}
    bucket[Test_Result::Terms]['buckets'].each { |sub_bucket|
      @pass_fail_rates[sub_bucket['key']] = 
        100.0 * sub_bucket['doc_count'].to_i / @total
    }
  end

  def id
    return @interval.to_s
  end

  def interval
    return @interval.to_i
  end

  def rate (pf)
    return @pass_fail_rates[pf]
  end
  
end

class Target < Test_Result
  Index = 'passrate_by_mileage'
  Test_Mileage_Interval = Test_Mileage::Field
  Id_Suffix = '_miles'

  @@operations = []

  def add (bucket)
    Scope.each {|pf|
      # Summary Entity is remapped here
      @@operations.concat [
        { index: { _index: Target::Index, 
          _type: 'doc', 
          _id: bucket.id+'_'+pf+Target::Id_Suffix, 
          data: { Target::Test_Mileage_Interval => bucket.interval, 
            pf_result: pf, 
            pass_rate: ( bucket.rate pf ) } } } ]
    }
  end

  def bulk_operations (client)
    client.bulk body: @@operations
  end
    
end

# MAIN - connect to Elasticsearch
es_client = Elasticsearch::Client.new log: true

source = Source.new
target = Target.new

source.query es_client

# iterate over 10K intervals
source.buckets.each { |raw_bucket| 
  target.add(
    Bucket.new(raw_bucket))
}

target.bulk_operations es_client
