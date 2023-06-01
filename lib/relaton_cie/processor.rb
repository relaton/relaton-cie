require "relaton/processor"

module RelatonCie
  class Processor < Relaton::Processor
    def initialize # rubocop:disable Lint/MissingSuper
      @short = :relaton_cie
      @prefix = "CIE"
      @defaultprefix = /^CIE(-|\s)/
      @idtype = "CIE"
      @datasets = %w[cie-techstreet]
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonCie::BibliographicItem]
    def get(code, date, opts)
      ::RelatonCie::CieBibliography.get(code, date, opts)
    end

    #
    # Fetch all the docukents from a source
    #
    # @param [String] _source source name
    # @param [Hash] opts
    # @option opts [String] :output directory to output documents
    # @option opts [String] :format
    #
    def fetch_data(_source, opts)
      DataFetcher.fetch(**opts)
    end

    # @param xml [String]
    # @return [RelatonCie::BibliographicItem]
    def from_xml(xml)
      ::RelatonCie::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonCie::BibliographicItem]
    def hash_to_bib(hash)
      ::RelatonCie::BibliographicItem.from_hash hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonCie.grammar_hash
    end

    #
    # Remove index file
    #
    def remove_index_file
      Relaton::Index.find_or_create(:cie, url: true, file: Scrapper::INDEX_FILE).remove_file
    end
  end
end
