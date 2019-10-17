require 'elasticsearch'

client = Elasticsearch::Client.new log: true

# query elastic to aggregate pass/fail to buckets in steps of 10K mileage
o = client.search index: 'mot_tests', 
  body: { query: { terms: { 'test_result.keyword' => [ "P", "F" ] } }, 
    aggs: { pf_by_test_mileage: { 
      histogram: { field: 'test_mileage', interval: 10000 }, 
      aggs: { pf: { terms: { field: 'test_result.keyword', size: 2 } } } } } }

# iterate over 10K intervals
o['aggregations']['pf_by_test_mileage']['buckets'].each { |b| 
  # init lazy /0 safe
  passes = 0
  fails = 1
  b['pf']['buckets'].each { |sb|
    if sb['key'] == 'P' 
      passes = sb['doc_count'].to_i 
    else 
      fails = sb['doc_count'].to_i
    end
  }

  # index the pass rate for the 10K bucket
  client.index  index: 'passrate_by_mileage', 
    type: 'doc', 
    id: b['key'].to_s+'_pass_miles', 
    body: { test_mileage: b['key'].to_i, 
      pf_result: 'P', 
      pass_rate: 100.0*passes/(fails+passes) }

  # index the fail (complement of pass) rate for the 10K bucket
  client.index  index: 'passrate_by_mileage', 
    type: 'doc', 
    id: b['key'].to_s+'_fail_miles', 
    body: { test_mileage: b['key'].to_i, 
      pf_result: 'F', 
      pass_rate: 100-(100.0*passes/(fails+passes)) }
}

