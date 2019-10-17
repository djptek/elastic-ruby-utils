require 'json'

File.open("municipios.json", "r") do |i_file|
	File.open("municipios.coordinates.ndjson", "w") do |o_file|
    i_file.each_line do |l|
  	####
      parsed = JSON.parse(l)
			parsed.each do |e|
				o = {}
  			o["provincia"] = e["provincia"]
  			o["municipio"] = e["capital"]
  			o["lat"] = e["latitud_etrs89"]
  			o["lon"] = e["longitud_etrs89"]
				o_file.puts(o.to_json)
  		end
    end
  end
end
