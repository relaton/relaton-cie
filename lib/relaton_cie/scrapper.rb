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

        parse_page "#{ENDPOINT}#{row[:file]}", code
      # rescue OpenURI::HTTPError => e
      #   return if e.io.status.first == "404"

      #   raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end

      private

      # @param url [String]
      # @retrurn [RelatoCie::BibliographicItem]
      def parse_page(url, code)
        resp = Mechanize.new.get url
        bib_hash = RelatonBib::HashConverter.hash_to_bib YAML.safe_load(resp.body)
        bib_hash[:fetched] = Date.today.to_s
        RelatonCie::BibliographicItem.new(**bib_hash)
      rescue Mechanize::ResponseCodeError => e
        return if e.response_code == "404"

        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      rescue Mechanize::RedirectLimitReachedError, Timeout::Error,
          Mechanize::UnauthorizedError, Mechanize::UnsupportedSchemeError,
          Mechanize::ResponseReadError, Mechanize::ChunkedTerminationError => e
        raise RelatonBib::RequestError, "No document found for #{code} reference. #{e.message}"
      end
    end
  end
end
