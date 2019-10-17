require 'json'

File.open("municipios_nested.txt", "r") do |i_file|
  File.open("municipios_denormalized.txt", "w") do |o_file|
    i_file.each_line do |l|
  	####
      parsed = JSON.parse(l)
  	  parsed["fiestas"].each do |f|
  			o = {}
  			o["provincia"] = parsed["provincia"]
  			o["municipio"] = parsed["municipio"]
  			o["date"] = f["date"]
  			o["fiesta"] = f["fiesta"]
				o_file.puts(o.to_json)
  		end
    end
  end
end
