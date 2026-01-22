require "mechanize"

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

          parse_page "#{ENDPOINT}#{row[:file]}", code
        end

        private

        # @param url [String]
        # @param code [String]
        # @retrurn [Relato::Cie::ItemData]
        def parse_page(url, code)
          resp = Mechanize.new.get url
          Item.from_yaml(resp.body).tap { |item| item.fetched = Date.today.to_s }
        rescue Mechanize::ResponseCodeError => e
          return if e.response_code == "404"

          raise Relaton::RequestError, "No document found for #{code} reference. #{e.message}"
        rescue Mechanize::RedirectLimitReachedError, Timeout::Error,
            Mechanize::UnauthorizedError, Mechanize::UnsupportedSchemeError,
            Mechanize::ResponseReadError, Mechanize::ChunkedTerminationError => e
          raise Relaton::RequestError, "No document found for #{code} reference. #{e.message}"
        end
      end
    end
  end
end
