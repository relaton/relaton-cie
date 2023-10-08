# frozen_string_literal:true

module RelatonCie
  # IETF bibliography module
  module CieBibliography
    class << self
      # @param code [String] the ECMA standard Code to look up (e..g "ECMA-6")
      # @return [RelatonBib::BibliographicEcma]
      def search(code)
        Scrapper.scrape_page code
      end

      # @param code [String] the ECMA standard Code to look up (e..g "ECMA-6")
      # @param year [String] not used
      # @param opts [Hash] not used
      # @return [RelatonCie::BibliographicItem] Relaton of reference
      def get(code, _year = nil, _opts = {})
        Util.warn "(#{code}) Fetching from Relaton repository ..."
        result = search code
        if result
          Util.warn "(#{code}) Found: `#{result.docidentifier.first.id}`"
        else
          Util.warn "(#{code}) Not found."
        end
        result
      end
    end
  end
end
