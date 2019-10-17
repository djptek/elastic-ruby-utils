#
# Export indices from Elasticsearch
require "elasticsearch"

class Source
    
  Max_Size = 10000
    
  def initialize(client)
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
    target = Target.new
    self.hits.each { |hit|
      # puts hit
      target.add(hit, @@es_client)
    }
    target.bulk_operations 
  end

  def query
    @search_results = @@es_client.search index: "blogs"
      scroll: '5m',
      body: {
        sort: ["_doc"],
        size: Max_Size,
        query: { "match_all": {} } }
    process_scroll_batch

    while @search_results = @@es_client.scroll(
      scroll_id: self.scroll_id, 
      scroll: '5m') and not self.hits.empty? 
      process_scroll_batch
    end
  end

end

class Target

  @@operations = ''
  @@index = 'log_blogs'

  def process_scroll_batch
    puts "Processing Scroll Batch ["+self.scroll_id.to_s+"]"
    target = Target.new
    self.hits.each { |hit|
      # puts hit
      target.add(hit, @@es_client)
    }
    target.bulk_operations 
  end

 
  def add(hit, es_client)
    @search_results = @@es_client.search index: "logs_server*"
      scroll: '5m',
      body: {
        sort: ["_doc"],
        size: Max_Size,
        query: { 
					"match": { 
						"originalUrl.keyword": hit.url.keyword 
    } } }
    process_scroll_batch

    while @search_results = es_client.scroll(
      scroll_id: self.scroll_id, 
      scroll: '5m') and not self.hits.empty? 
      process_scroll_batch
    end
            
    @@operations.concat '{ "index" : { "_index" : "'+hit["_index"]+
          '", "_type" : "'+hit["_type"]+
          '", "_id" : "'+hit["_id"]+"\"} }\n"+
          hit["_source"].to_json+"\n" 
  end

  def bulk_operations
    # client.bulk body: @@operations
    open(@@index+'_bulk.txt', 'a') { |f|
      f << @@operations
    }
    @@operations = ''
  end

end

# MAIN - connect to Elasticsearch
Source.new(Elasticsearch::Client.new log: false).query
  

