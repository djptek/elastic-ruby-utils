require 'nokogiri'

####
# xml file from which the document content is extracted
class Parsed_XML
    
  # MAX_SIZE = 1
    
  def initialize source_filename:
    # workaround for https://github.com/sparklemotion/nokogiri/issues/1127
    @doc = Nokogiri::XML(IO.
      read(source_filename, mode: 'r', encoding: 'utf-8').
      gsub(/&amp;/, ':PRESERVEAMPERSAND:').
      gsub(/&gt;/, ':PRESERVEGT:').
      gsub(/&lt;/, ':PRESERVELT:')) {|config| config.recover.noent}
    @index = source_filename.
          sub($source_dir,'').
          sub($from_rhs,'').
          downcase
  end

  def h1_as_filename
    return (@doc.xpath '//h1//text()').text.downcase.gsub(/\W/,'_')
  end

  # accessor for text nodes
  def text_nodes
    return @doc.xpath '//body//text()'
  end
    
  def traverse_nodes
    solutions = ''
    text_nodes.each do |node|
      #puts node.path
      solutions << "######\n\n#{node.text.
        gsub(':PRESERVEAMPERSAND:', '&').
        gsub(':PRESERVEGT:', '>').
        gsub(':PRESERVELT:', '<')}\n\n" if 
          node.path.end_with?( 'h1/text()', 'h2/text()') or
          node.text.start_with?( 'GET ', 'PUT ', 'POST ', 'DELETE ')
    end
    return solutions
  end

end

####
# iterate over all XML files in local folder
$source_dir = "./"
$prefix     = "labs/"
$from_rhs   = "*.html"
$to_rhs     = "_requests.txt"
$target_dir = "./"
Dir[$source_dir+$prefix+$from_rhs].each do |in_file| 
  parsed = Parsed_XML.
      new(source_filename: in_file)
  puts('parsing '+parsed.h1_as_filename)  
  File.open($prefix+parsed.h1_as_filename+$to_rhs, 'w') do |out_file| 
    out_file.write(parsed.
      traverse_nodes)
  end
end
