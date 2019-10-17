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
			puts "Adding hit ["+hit["_id"]+"]"
      target.add(hit)
    }
    target.bulk_operations 
  end

  def query
    @search_results = @@es_client.search index: "*",
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
  @@index = ''
 
  def add(hit)
    if hit["_index"] != @@index
        self.bulk_operations unless @@index == ''
        @@index = hit["_index"]
    end
            
    @@operations.concat '{ "index" : { "_index" : "'+hit["_index"]+
          '", "_id" : "'+hit["_id"]+"\"} }\n"+
          hit["_source"].to_json+"\n" 
  end

  def bulk_operations
    # client.bulk body: @@operations
    puts "Writing bulk file ["+@@index+"_bulk.txt]"
    open(@@index+'_bulk.txt', 'a') { |f|
      f << @@operations
    }
    @@operations = ''
  end

end

# MAIN - connect to Elasticsearch
#Source.new(Elasticsearch::Client.new log: false).query
Source.new(Elasticsearch::Client.new(:hosts => "http://elastic:password@server1:9200") ).query

