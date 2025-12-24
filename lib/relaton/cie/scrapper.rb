module Relaton
  module Cie
    module Scrapper
      ENDPOINT = "https://raw.githubusercontent.com/relaton/relaton-data-cie/refs/heads/data-v2/".freeze
      INDEX_FILE = "index-v1.yaml".freeze

      class << self
        # @param code [String]
        # @return [Relaton::Cie::ItemData]
        def scrape_page(code)
          index = Index.find_or_create :cie, url: "#{ENDPOINT}index-v1.zip", file: INDEX_FILE
          row = index.search(code).min_by { |r| r[:id] }
          return unless row

          parse_page "#{ENDPOINT}#{row[:file]}"
        rescue OpenURI::HTTPError => e
          return if e.io.status.first == "404"

          raise RequestError, "No document found for #{code} reference. #{e.message}"
        end

        private

        # @param url [String]
        # @retrurn [Relato::Cie::ItemData]
        def parse_page(url)
          doc = OpenURI.open_uri url
          Item.from_yaml(doc).tap { |item| item.fetched = Date.today.to_s }
        end
      end
    end
  end
end
