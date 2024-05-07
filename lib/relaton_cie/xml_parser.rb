module RelatonCie
  module XMLParser
    include RelatonBib::Parser::XML
    extend self
    # @param item_hash [Hash]
    # @return [RelatonCie::BibliographicItem]
    def bib_item(item_hash)
      BibliographicItem.new(**item_hash)
    end
  end
end
