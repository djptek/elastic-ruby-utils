# Create Entity Table in Elastic
# * Extracts aggregations from Elasticsearch
# * Creates geo_shapes
# * Performs a bulk index 
require "elasticsearch"
require "json"

module Geo_Lookup
	Comunidad_Location = {"ANDALUCÍA" => [-5.98,37.37], "ARAGÓN" => [-0.88,41.66], "ASTURIAS" => [-5.85,43.36], "ILLES BALEARS" => [-2.65,39.57], "CANARIAS"  => [-15.42,28.15], "CANTABRIA" => [-3.80,43.45], "CASTILLA-LA MANCHA" => [-4.03,39.86], "CASTILLA Y LEÓN" => [-4.72,41.63], "CATALUÑA" => [2.17,41.38], "CIUDAD DE CEUTA" => [-5.32,35.89], "EXTREMADURA" => [-6.33,38.90], "GALICIA" => [-8.55,42.87], "LA RIOJA" => [-2.45,42.46], "MADRID" => [-3.68,40.43], "CIUDAD DE MELILLA" => [-2.94,35.29], "MURCIA" => [-1.13,37.99], "NAVARRA" => [-1.64,42.82], "COMUNITAT VALENCIANA" => [-0.38,39.47], "PAÍS VASCO" => [-2.68,42.85]}
end

module Source_Index
  Name = "fiestas_vs_comunidad_autonoma"
end 

module Target_Index
  Name = "comunidad_autonoma_vs_fiestas"
end 

class Source
  include Source_Index, Geo_Lookup

  Max_Size = 20

  def initialize (client)
    @@es_client = client
#		@@es_client.indices.put_mapping index: Source_Index::Name, 
#			type: '_doc', 
#			body: {
#               mappings: {
#                 properties: {
#                   'comunidad': { type: 'keyword'},
#									 'fiesta': {
#                     'properties': {
#                       'date': {
#                         type: 'date'
#                       },
#                       'location': {
#                         type: 'geo_point'
#                       },
#                       'name': {
#                         type: 'keyword'
#                         }
#                       }
#                     }
#                 }
#               }
#             }
  end

  def query
    @search_results = @@es_client.search index: Source_Index::Name,
         body: {
          size: 0,
          aggs: { 
						my_comunidades: { 
							terms: { "field" => "comunidades" , "size" => Max_Size },
							aggs: { 
								my_local_fiestas: {
									top_hits: {
									  _source: { includes: ["date", "fiesta"] },
										size: 14 }
						} } } } }
    #puts @search_results
    @target = Target.new(@@es_client)
    @search_results["aggregations"]["my_comunidades"]["buckets"].each { |bucket|
      puts "adding comunidad => "+bucket["key"].to_s
      @target.add(bucket)
    }
    @target.bulk_operations
    
  end

end

class Target
	include Target_Index
  
  def initialize (client)
    @@es_client = client
#   @@es_client.indices.delete index: Target_Index::Name
#   @@es_client.indices.put_mapping index: Target_Index::Name, 
#   type: 'mytype', 
#			body: {
#               mappings: {
#                 properties: {
#                   'comunidad': { type: 'keyword'},
#									 'fiesta': {
#                     'properties': {
#                       'date': {
#                         type: 'date'
#                       },
#                       'location': {
#                         type: 'geo_point'
#                       },
#                       'name': {
#                         type: 'keyword'
#                         }
#                       }
#                     }
#                 }
#               }
#             }
	end

  @@operations = []

  def add (comunidad)
    # puts "\tretrieving history"
		comunidad["my_local_fiestas"]["hits"]["hits"].each { |fiesta|
      @@operations.concat [
        { index: { _index: Target_Index::Name,
								   _id: comunidad["key"]+":"+fiesta["_source"]["date"],
          data: { "comunidad" => comunidad["key"],
					  "fiesta" => { 
              "name" => fiesta["_source"]["fiesta"],
              "date" => fiesta["_source"]["date"],
					    "location" => Geo_Lookup::Comunidad_Location[comunidad["key"]]
				  }}}}]
		}
  end

  def bulk_operations 
    # puts @@operations
    @@es_client.bulk body: @@operations unless 
      @@operations.length == 0
  end

end

# MAIN - connect to Elasticsearch
source = Source.new(Elasticsearch::Client.new(:hosts => "http://elastic:ch3353@server1:9200") ).query
  

