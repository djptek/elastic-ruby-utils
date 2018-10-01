# Create a bulk file to be submitted with e.g. 
=begin
for b in S3V*_bulk.txt 
do curl -X POST "localhost:9200/_bulk" \
-H 'Content-Type: application/json' \
--data-binary '@'$b ; 
done
=end
# note: dump to *_bulk.txt 
# require 'elasticsearch'
require 'nokogiri'
require 'json'

####
# xml file from which the document content is extracted
class Parsed_XML
    
  # MAX_SIZE = 1
    
  def initialize source_filename:
    @doc = Nokogiri::XML File.open source_filename
    @index = source_filename.
          sub($source_dir,'').
          sub($from_rhs,'').
          downcase
  end

  # accessor for <p/> elements
  def p_elements
    return @doc.xpath '//p'
  end
    
  def traverse_elements
    bulk_ops = Bulk_Operations::new 
    p_elements.each do |p|
      # ignore elements where no membercontribution present
      bulk_ops::add index: @index, p: p  unless 
        not p.at_xpath 'membercontribution'
    end
    return bulk_ops
  end

end

####
# build _bulk NDJSON files (rather than direct index) for portability 
class Bulk_Operations

  def initialize
    @operations = ''
  end
   
  # Each _bulk consists of request +...
  class Request < Hash
      
    def initialize index:, id:
      self[:index] = Hash::new
      self[:index][:_index] = index
      self[:index][:_type] = :_doc
      self[:index][:_id] = id
    end
      
  end 
    
  # Payload
  class Payload < Hash
      
    def initialize member:, membercontribution:
      self[:member] = member
      self[:membercontribution] = membercontribution
    end

  end
    
  def add index:, p:
    @operations.concat Request::new(
        index: index,
        id: p.xpath('@id').text).
          to_json+"\n"
    @operations.concat Payload::new(
        member: p.xpath('member').text, 
        membercontribution: p.xpath('membercontribution').text).
          to_json+"\n"
  end

  def export_to convert_filename:
    open convert_filename.
      sub($source_dir, $target_dir).
      sub($from_rhs, $to_rhs), 'w'  do |f|
      f << @operations
    end
  end

end

# MAIN - 
# iterate over all XML files in local folder
$source_dir = "../raw/"
$prefix     = "S3V*"
$from_rhs   = ".xml"
$to_rhs     = "_bulk.txt"
$target_dir = "../bulk/"
Dir[$source_dir+$prefix+$from_rhs].each do |x| 
    puts "Processing "+x
    Parsed_XML.new(source_filename: x).
        traverse_elements.
        export_to convert_filename: x
end
