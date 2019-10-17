(0..2).each {|shards_magnitude| 
	shards = 10**shards_magnitude
  (0..2).each {|nodes_magnitude| 
	  nodes = 10**nodes_magnitude
    (0..2).each {|racks_magnitude| 
	    racks = 10**racks_magnitude
			if racks <= nodes && shards >= nodes
			  printf("foo %d %d %d\n", shards, nodes, racks)
			end
		}
	}
}
