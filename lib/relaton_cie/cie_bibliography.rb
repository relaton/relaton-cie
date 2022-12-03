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
        warn "[relaton-cie] (\"#{code}\") fetching..."
        result = search code
        if result
          warn "[relaton-cie] (\"#{code}\") found #{result.docidentifier.first.id}"
        else
          warn "[relaton-cie] WARNING no match found online for #{code}. " \
               "The code must be exactly like it is on the standards website."
        end
        result
      end
    end
  end
end
