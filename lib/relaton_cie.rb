require "nokogiri"
require "open-uri"
# require "parslet"
require "relaton/index"
require "relaton_bib"
# require "relaton_bib/name_parser"
require "relaton_cie/version"
require "relaton_cie/util"
require "relaton_cie/bibliographic_item"
require "relaton_cie/cie_bibliography"
require "relaton_cie/scrapper"
require "relaton_cie/data_fetcher"
require "relaton_cie/xml_parser"
require "relaton_cie/hash_converter"

module RelatonCie
  # Returns hash of XML reammar
  # @return [String]
  def self.grammar_hash
    # gem_path = File.expand_path "..", __dir__
    # grammars_path = File.join gem_path, "grammars", "*"
    # grammars = Dir[grammars_path].sort.map { |gp| File.read gp }.join
    Digest::MD5.hexdigest RelatonCie::VERSION + RelatonBib::VERSION # grammars
  end
end
