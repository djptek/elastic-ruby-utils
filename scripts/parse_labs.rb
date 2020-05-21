require 'nokogiri'

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

  # accessor for <code/> elements
  def code_elements
    #return @doc.xpath '//'
    return @doc.xpath '//body//text()'
  end
    
  def traverse_elements
    solutions = ''
    code_elements.each do |code|
      solutions << "######\n\n#{code.text}\n\n" if 
        code.path.end_with?( 'h1/text()', 'h2/text()') or
        code.text.start_with?( 'GET ', 'PUT ', 'POST ', 'DELETE ')
    end
    return solutions
  end

end

####
# iterate over all XML files in local folder
$source_dir = "./"
$prefix     = "labs/*"
$from_rhs   = ".html"
$to_rhs     = "_solutions.txt"
$target_dir = "./"
Dir[$source_dir+$prefix+$from_rhs].each do |in_file| 
  File.open(in_file.sub($from_rhs, $to_rhs), 'w') do |out_file| 
    out_file.write(Parsed_XML.
      new(source_filename: in_file).
      traverse_elements)
  end
end
