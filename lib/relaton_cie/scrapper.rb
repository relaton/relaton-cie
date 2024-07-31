module RelatonCie
  module Scrapper
    ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-cie/main/".freeze
    INDEX_FILE = "index-v1.yaml".freeze

    class << self
      # @param code [String]
      # @return [RelatonCie::BibliographicItem]
      def scrape_page(code)
        index = Relaton::Index.find_or_create :cie, url: "#{ENDPOINT}index-v1.zip", file: INDEX_FILE
        row = index.search(code).min_by { |r| r[:id] }
        return unless row

        parse_page "#{ENDPOINT}#{row[:file]}"
      rescue OpenURI::HTTPError => e
        return if e.io.status.first == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end

      private

      # @param url [String]
      # @retrurn [RelatoCie::BibliographicItem]
      def parse_page(url)
        doc = OpenURI.open_uri url
        bib_hash = RelatonBib::HashConverter.hash_to_bib YAML.safe_load(doc)
        bib_hash[:fetched] = Date.today.to_s
        RelatonCie::BibliographicItem.new(**bib_hash)
      end
    end
  end
end
