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

class Target < Test_Result
  Index = 'passrate_by_mileage'
  Test_Mileage_Interval = Test_Mileage::Field
  Id_Suffix = '_miles'

  def pass_fail_rate (pf, test_results)
    pass_rate = 100.0*test_results[Test_Result::Pass]/
      (test_results[Test_Result::Fail]+test_results[Test_Result::Pass]) 
    if pf == Test_Result::Pass
       return pass_rate
    else
       return 100-pass_rate
    end 
  end

  def initialize (b, sbs)
    @bucket = b
    @values = {}
    @pass_fail_rates = {}
    sbs.each { |sub_bucket|
      @values[sub_bucket['key']] = sub_bucket['doc_count'].to_i
    }
    Scope.each {|pf| 
      @pass_fail_rates[pf] = pass_fail_rate pf, 
        {Test_Result::Pass => @values[Pass], 
         Test_Result::Fail => @values[Fail]}
    }
  end

  def index (client)
    Scope.each {|pf|
    # index the pass/fail rate for the 10K bucket
    client.index  index: Target::Index, 
      type: 'doc', 
      id: @bucket.to_s+'_'+pf+Target::Id_Suffix, 
      body: { Target::Test_Mileage_Interval => @bucket.to_i, 
        pf_result: pf, 
        pass_rate: ( @pass_fail_rates[pf] )}
    }
  end
end

# MAIN - connect to Elasticsearch
es_client = Elasticsearch::Client.new log: true

source = Source.new
source.query es_client

# iterate over 10K intervals
source.buckets.each { |bucket| 
  Target.new(bucket['key'],
    bucket[Test_Result::Terms]['buckets']).index es_client
}
