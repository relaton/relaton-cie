require "relaton/processor"

module RelatonCie
  class Processor < Relaton::Processor
    def initialize
      @short = :relaton_cie
      @prefix = "CIE"
      @defaultprefix = /^CIE(-|\s)/
      @idtype = "CIE"
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonBib::BibliographicItem]
    def get(code, date, opts)
      ::RelatonCie::CieBibliography.get(code, date, opts)
    end

    # @param xml [String]
    # @return [RelatonBib::BibliographicItem]
    def from_xml(xml)
      ::RelatonBib::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonBib::BibliographicItem]
    def hash_to_bib(hash)
      ::RelatonBib::BibliographicItem.from_hash hash
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonEcma.grammar_hash
    end
  end
end
