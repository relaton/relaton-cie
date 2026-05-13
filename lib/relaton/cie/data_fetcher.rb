# frozen_string_literal: true

require "English"
require "fileutils"
require "ferrum"
require "nokogiri"
require "relaton/index"
require "relaton/bib"
require "relaton/core/data_fetcher"
require_relative "../cie"

module Relaton
  module Cie
    # Thin Ferrum-backed HTTP agent that mimics the Mechanize#get interface
    # used elsewhere in DataFetcher. Drives headless Chrome with stealth
    # tweaks so the CIE catalogue host (Cloudflare-protected accuristech)
    # serves real HTML instead of a "Just a moment..." challenge.
    class BrowserAgent
      UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
           "(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36"
      CHALLENGE_MARKERS = ["Just a moment", "challenge-platform"].freeze
      MAX_CHALLENGE_WAIT = 30

      def initialize
        @browser = Ferrum::Browser.new(
          headless: true,
          timeout: 90,
          process_timeout: 90,
          window_size: [1366, 768],
          browser_options: {
            "disable-blink-features" => "AutomationControlled",
            "disable-quic" => nil,
            "no-sandbox" => nil
          }
        )
        @browser.headers.set(
          "Accept-Language" => "en-US,en;q=0.9",
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9," \
                      "image/webp,*/*;q=0.8",
          "User-Agent" => UA
        )
        # Pre-mask the most common headless-Chrome tells before any page JS runs.
        @browser.evaluate_on_new_document(<<~JS)
          Object.defineProperty(navigator, 'webdriver', { get: () => undefined });
          Object.defineProperty(navigator, 'languages', { get: () => ['en-US', 'en'] });
          Object.defineProperty(navigator, 'plugins', { get: () => [1,2,3,4,5] });
          window.chrome = { runtime: {} };
        JS
      end

      def get(url)
        @browser.go_to(url)
        wait_for_challenge
        Nokogiri::HTML(@browser.body)
      end

      def quit
        @browser&.quit
      ensure
        @browser = nil
      end

      private

      def wait_for_challenge
        MAX_CHALLENGE_WAIT.times do
          return unless CHALLENGE_MARKERS.any? { |m| @browser.body.include?(m) }

          sleep 1
        end
      end
    end

    class DataFetcher < Relaton::Core::DataFetcher
      URL = "https://www.techstreet.com/cie/searches/31156444?page=1&per_page=100"

      def agent
        @agent ||= BrowserAgent.new
      end

      def index
        @index ||= Index.find_or_create :cie, file: "index-v1.yaml"
      end

      def log_error(msg)
        Util.error msg
      end

      # @param hit [Nokogiri::HTML::Document]
      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::Docidentifier>]
      def fetch_docid(hit, doc)
        code, code2 = parse_code hit, doc
        docid = []
        if code && !code.strip.empty?
          docid << Bib::Docidentifier.new(type: "CIE", content: code, primary: true)
          @errors[:docid_1] &&= false
        else
          @errors[:docid_1] &&= true
        end
        if code2 && !code2.strip.empty?
          type2 = code2.match(/\w+/).to_s
          docid << Relaton::Bib::Docidentifier.new(type: type2, content: code2.strip)
          @errors[:docid_2] &&= false
        else
          @errors[:docid_2] &&= true
        end
        isbn = doc.at('//h3[contains(.,"ISBN")]/following-sibling::span')&.text
        if isbn && !isbn.strip.empty?
          docid << Bib::Docidentifier.new(type: "ISBN", content: isbn)
          @errors[:docid_isbn] &&= false
        else
          @errors[:docid_isbn] &&= true
        end
        docid
      end

      def parse_code(hit, doc = nil)
        code = hit.at("h3/a").text.strip.squeeze(" ").sub(/\u25b9/, "").gsub(" / ", "/")
        c2idx = %r{(?:\(|/)(?<c2>(?:ISO|IEC)\s[^()]+)} =~ code
        code = code[0...c2idx].strip if c2idx
        [primary_code(code, doc), c2]
      end

      def primary_code(code, doc = nil)
        /^(?<code1>[^(]+)(?:\((?<code2>[a-zA-Z]+\d+,(?:\sPages)?[^)]+))?/ =~ code
        if code1&.match?(/^CIE/)
          parse_cie_code code1, code2, doc
        elsif (pcode = doc&.at('//h3[.="Product Code(s):"]/following-sibling::span'))
          "CIE #{pcode.text.strip.match(/[^,]+/)}"
        else
          num = code.match(/(?<=\()\w{2}\d+,.+(?=\))/).to_s.gsub(/,(?=\s)/, "").gsub(/,(?=\S)/, " ")
          "CIE #{num}"
        end
      end

      def parse_cie_code(code1, code2, doc = nil) # rubocop:disable Metrics/CyclomaticComplexity
        code = code1.size > 25 && code2 ? "CIE #{code2.sub(/,(\sPages)?/, '')}" : code1
        add = doc&.at("//hgroup/h2")&.text&.match(/(Add)endum\s(\d+)$/)
        return code unless add

        "#{code} #{add[1]} #{add[2]}"
      end

      def fetch_docnumber(hit)
        parse_code(hit).first.sub(/^CIE\s(?:ISO\s)?/, "")
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::Title>]
      def fetch_title(doc)
        t = doc.at("//hgroup/h2/text()", "//hgroup/h1/text()")
        unless t && !t.text.strip.empty?
          @errors[:title] &&= true
          return []
        end

        result = Bib::Title.from_string t.text.strip
        @errors[:title] &&= result.empty?
        result
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::Date>]
      def fetch_date(doc)
        result = doc.xpath("//h3[.='Published:']/following-sibling::span").map do |d|
          pd = d.text.strip
          on = pd.match?(/^\d{4}(?:[^-]|$)/) ? pd : Date.strptime(pd, "%m/%d/%Y").strftime("%Y-%m-%d")
          Bib::Date.new(type: "published", at: on)
        end
        @errors[:date] &&= result.empty?
        result
      end

      # @param doc [Mechanize::Page]
      # @return [String]
      def fetch_edition(doc)
        ed = doc.at("//h3[.='Edition:']/following-sibling::span")
        @errors[:edition] &&= true
        return unless ed

        content = ed.text.slice(/^\d+(?=(st|nd|rd|th))/)
        if content
          @errors[:edition] = false
          Bib::Edition.new(content: content)
        end
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Cie::Relation>]
      def fetch_relation(doc) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        rels = doc.xpath('//section[@class="history"]/ol/li[not(contains(@class,"selected-product"))]').map do |rel|
          ref = rel.at("a")
          url = "https://www.techstreet.com#{ref[:href]}"
          title = Bib::Title.from_string ref.at('p/span[@class="title"]').text
          did = ref.at("h3").text
          docid = [Bib::Docidentifier.new(type: "CIE", content: did, primary: true)]
          on = ref.at("p/time")
          date = [Bib::Date.new(type: "published", at: on[:datetime])]
          source = [Bib::Uri.new(type: "src", content: url)]
          bibitem = ItemData.new docidentifier: docid, title: title, source: source, date: date
          type = ref.at('//li/i[contains(@class,"historical")]') ? "updates" : "updatedBy"
          Bib::Relation.new(type: type, bibitem: bibitem)
        end
        @errors[:relation] &&= rels.empty?
        rels
      end

      # @param url [String]
      # @return [Array<Relaton::Bib::Uri>]
      def fetch_source(url)
        @errors[:source] &&= url.nil? || url.empty?
        return [] if url.nil? || url.empty?

        [Bib::Uri.new(type: "src", content: url)]
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::LocalizedMarkedUpString>]
      def fetch_abstract(doc)
        content = doc.at('//div[contains(@class,"description")]')&.text&.strip
        if content.nil? || content.empty?
          @errors[:abstract] &&= true
          return []
        end

        result = [Bib::Abstract.new(content: content, language: "en", script: "Latn")]
        @errors[:abstract] &&= result.empty?
        result
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::Contributor>]
      def fetch_contributor(doc) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength,Metrics/CyclomaticComplexity
        authors = doc.xpath('//hgroup/p[not(@class="pub_date")]').text.gsub "\"", ""
        contribs = []
        until authors.empty?
          /^(?<sname1>\S+(?:\sder?\s)?[^\s,]+)
          (?:,?\s(?<sname2>[\w-]{2,})(?=,\s+\w\.))?
          (?:,?\s(?<fname>W-T\.[\w-]{2,})(?!,\s+\w\.))?
          (?:(?:\s?,\s?|\s)(?<init>(?:\w(?:\s?\.|\s|,|$)[\s-]?)+))?
          (?:(?:[,;]\s*|\s+|\.|(?<=\s))(?:and\s)?)?/x =~ authors
          raise StandardError, "Author name not found in \"#{authors}\"" unless $LAST_MATCH_INFO

          authors.sub! $LAST_MATCH_INFO.to_s, ""
          sname = [sname1, sname2].compact.join " "
          surname = Bib::LocalizedString.new content: sname, language: "en", script: "Latn"
          forename = []
          forename << Bib::FullNameType::Forename.new(content: fname, language: "en", script: "Latn") if fname
          (init&.strip || "").split(/(?:,|\.)(?:-|\s)?/).each do |int|
            forename << Bib::FullNameType::Forename.new(content: "", initial: int.strip, language: "en", script: "Latn")
          end
          fullname = Bib::FullName.new surname: surname, forename: forename
          person = Bib::Person.new name: fullname
          role = Bib::Contributor::Role.new type: "author"
          contribs << Bib::Contributor.new(person: person, role: [role])
          @errors[:contributor_author] &&= contribs.empty?
        end
        org_name = Bib::TypedLocalizedString.new(content: "Commission Internationale de L'Eclairage")
        abbrev = Bib::LocalizedString.new content: "CIE"
        org_uri = Bib::Uri.new content: "cie.co.at"
        org = Bib::Organization.new(name: [org_name], abbreviation: abbrev, uri: [org_uri])
        org_role = Bib::Contributor::Role.new type: "publisher"
        contribs << Bib::Contributor.new(organization: org, role: [org_role])
      end

      def fetch_ext
        Ext.new(doctype: fetch_doctype, flavor: "cie")
      end

      def fetch_doctype
        Bib::Doctype.new(content: "document")
      end

      # @param bib [RelatonCie::BibliographicItem]
      def write_file(bib) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        id = bib.docidentifier[0].content
        file = output_file id
        if @files.include? file
          Util.warn do
            "File #{file} exists. Docid: #{bib.docidentifier[0].content}\n" \
            "Link: #{bib.source.detect { |l| l.type == 'src' }.content}"
          end
        else @files << file
        end
        index.add_or_update bib.docidentifier[0].content, file
        File.write file, serialize(bib), encoding: "UTF-8"
      end

      def to_xml(bib) = bib.to_xml(bibdata: true)
      def to_yaml(bib) = bib.to_yaml
      def to_bibxml(bib) = bib.to_rfcxml

      # @param hit [Nokogiri::HTML::Element]
      def parse_page(hit) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        url = hit.at('h3/a')[:href]
        doc = time_req { agent.get url }
        item = ItemData.new(
          type: "standard", source: fetch_source(url), docnumber: fetch_docnumber(hit),
          docidentifier: fetch_docid(hit, doc), title: fetch_title(doc),
          abstract: fetch_abstract(doc), date: fetch_date(doc),
          edition: fetch_edition(doc), contributor: fetch_contributor(doc),
          relation: fetch_relation(doc), language: "en", script: "Latn",
          ext: fetch_ext
        )
        write_file item
      rescue StandardError => e
        Util.error do
          "Document: #{url}\n#{e.message}\n#{e.backtrace}"
        end
      end

      def fetch(_source = nil)
        fetch_doc
        report_errors
      ensure
        @agent&.quit
      end

      def fetch_doc(url = URL)
        result = time_req { agent.get url }
        result.xpath("//li[@data-product]").each { |hit| parse_page hit }
        np = result.at '//a[@class="next_page"]'
        if np
          next_href = np[:href]
          next_url = next_href.start_with?("http") ? next_href : "https://www.techstreet.com#{next_href}"
          fetch_doc next_url
        else
          index.save
        end
      end

      RETRIABLE_ERRORS = [
        SocketError,
        Ferrum::TimeoutError,
        Ferrum::PendingConnectionsError,
        Ferrum::StatusError
      ].freeze

      def time_req
        tries = 0
        begin
          tries += 1
          sleep [4 - (Time.now - @last_request_time).to_i, 0].max if @last_request_time
          yield
        rescue *RETRIABLE_ERRORS => e
          retry if tries < 4
          raise e
        ensure
          @last_request_time = Time.now
        end
      end
    end
  end
end
