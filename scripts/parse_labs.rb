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
    return @doc.xpath '//code'
  end
    
  def traverse_elements
    solutions = ''
    code_elements.each do |code|
      # ignore elements where no membercontribution present
			solutions << "######\n\n#{code.text}\n\n"
    end
    return solutions
  end

end

####
# iterate over all XML files in local folder
$source_dir = "./"
$prefix     = "labs"
$from_rhs   = ".html"
$to_rhs     = "_solutions.txt"
$target_dir = "./"
Dir[$source_dir+$prefix+$from_rhs].each do |x| 
	  #p "processing #{x}"
		puts Parsed_XML.new(source_filename: x).
			traverse_elements
end
