module RelatonCie
  class XMLParser < RelatonBib::XMLParser
    class << self
      private

      # @param item_hash [Hash]
      # @return [RelatonCie::BibliographicItem]
      def bib_item(item_hash)
        BibliographicItem.new(**item_hash)
      end
    end
  end
end
