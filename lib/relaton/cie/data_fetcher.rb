# frozen_string_literal: true

require "English"
require "fileutils"
require "mechanize"
require "relaton/index"
require "relaton/bib"
require "relaton/core/data_fetcher"
require_relative "../cie"

module Relaton
  module Cie
    class DataFetcher < Relaton::Core::DataFetcher
      URL = "https://www.techstreet.com/cie/searches/31156444?page=1&per_page=100"

      def agent
        return @agent if @agent

        @agent = Mechanize.new
        @agent.request_headers = {
          "Accept" => "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
          "Accept-Language" => "en-US,en;q=0.5",
          "Connection" => "keep-alive",
          "sec-ch-ua" => '"Chromium";v="91", "Google Chrome";v="91", ";Not A Brand";v="99"',
          "Sec-Fetch-Dest" => "document"
        }
        @agent.user_agent_alias = "Linux Firefox"
        @agent
      end

      def index
        @index ||= Index.find_or_create :cie, file: "index-v1.yaml"
      end

      # @param hit [Nokogiri::HTML::Document]
      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::Docidentifier>]
      def fetch_docid(hit, doc)
        code, code2 = parse_code hit, doc
        docid = [Bib::Docidentifier.new(type: "CIE", content: code, primary: true)]
        if code2
          type2 = code2.match(/\w+/).to_s
          docid << Relaton::Bib::Docidentifier.new(type: type2, content: code2.strip)
        end
        isbn = doc.at('//h3[contains(.,"ISBN")]/following-sibling::span')
        docid << Bib::Docidentifier.new(type: "ISBN", content: isbn.text.strip) if isbn
        docid
      end

      def parse_code(hit, doc = nil)
        code = hit.at("h3/a").text.strip.squeeze(" ").sub(/\u25b9/, "").gsub(" / ", "/")
        c2idx = %r{(?:\(|/)(?<c2>(?:ISO|IEC)\s[^()]+)} =~ code
        code = code[0...c2idx].strip if c2idx
        [primary_code(code, doc), c2]
      end

      def primary_code(code, doc = nil)
        /^(?<code1>[^(]+)(?:\((?<code2>\w+\d+,(?:\sPages)?[^)]+))?/ =~ code
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
        t = doc.at("//hgroup/h2", "//hgroup/h1")
        return [] unless t

        Bib::Title.from_string t.text.strip
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::Date>]
      def fetch_date(doc)
        doc.xpath("//h3[.='Published:']/following-sibling::span").map do |d|
          pd = d.text.strip
          on = pd.match?(/^\d{4}(?:[^-]|$)/) ? pd : Date.strptime(pd, "%m/%d/%Y").strftime("%Y-%m-%d")
          Bib::Date.new(type: "published", at: on)
        end
      end

      # @param doc [Mechanize::Page]
      # @return [String]
      def fetch_edition(doc)
        ed = doc.at("//h3[.='Edition:']/following-sibling::span")
        return unless ed

        content = ed.text.slice(/^\d+(?=(st|nd|rd|th))/)
        Bib::Edition.new(content: content) if content
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Cie::Relation>]
      def fetch_relation(doc) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        doc.xpath('//section[@class="history"]/ol/li[not(contains(@class,"selected-product"))]').map do |rel|
          ref = rel.at("a")
          url = "https://www.techstreet.com#{ref[:href]}"
          title = Bib::Title.from_string ref.at('p/span[@class="title"]').text
          did = ref.at("h3").text
          docid = [Bib::Docidentifier.new(type: "CIE", content: did, primary: true)]
          on = ref.at("p/time")
          date = [Bib::Date.new(type: "published", at: on[:datetime])]
          source = [Bib::Uri.new(type: "src", content: url)]
          bibitem = Bib::ItemData.new docidentifier: docid, title: title, source: source, date: date
          type = ref.at('//li/i[contains(@class,"historical")]') ? "updates" : "updatedBy"
          Bib::Relation.new(type: type, bibitem: bibitem)
        end
      end

      # @param url [String]
      # @return [Array<Relaton::Bib::Uri>]
      def fetch_source(url)
        [Bib::Uri.new(type: "src", content: url)]
      end

      # @param doc [Mechanize::Page]
      # @return [Array<Relaton::Bib::LocalizedMarkedUpString>]
      def fetch_abstract(doc)
        content = doc.at('//div[contains(@class,"description")]')&.text&.strip
        return [] if content.nil? || content.empty?

        [Bib::LocalizedMarkedUpString.new(content: content, language: "en", script: "Latn")]
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
        id = bib.docidentifier[0].content.gsub(%r{[/\s\-:.]}, "_")
        file = "#{@output}/#{id.upcase}.#{@format}"
        if @files.include? file
          Util.warn do
            "File #{file} exists. Docid: #{bib.docidentifier[0].content}\n" \
            "Link: #{bib.source.detect { |l| l.type == 'src' }.content}"
          end
        else @files << file
        end
        index.add_or_update bib.docidentifier[0].content, file
        File.write file, content(bib), encoding: "UTF-8"
      end

      def content(bib)
        case @format
        when "xml" then bib.to_xml(bibdata: true)
        when "yaml" then bib.to_yaml
        when "bibxml" then bib.to_bibxml
        end
      end

      # @param hit [Nokogiri::HTML::Element]
      def parse_page(hit) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        url = hit.at('h3/a')[:href]
        doc = time_req { agent.get url }
        item = Bib::ItemData.new(
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
      end

      def fetch_doc(url = URL)
        result = time_req { agent.get url }
        result.xpath("//li[@data-product]").each { |hit| parse_page hit }
        np = result.at '//a[@class="next_page"]'
        if np
          fetch_doc "https://www.techstreet.com#{np[:href]}"
        else
          index.save
        end
      end

      def time_req
        tries = 0
        begin
          tries += 1
          sleep [4 - (Time.now - @last_request_time).to_i, 0].max if @last_request_time
          yield
        rescue Socket::ResolutionError => e
          retry if tries < 4
          raise e
        ensure
          @last_request_time = Time.now
        end
      end
    end
  end
end
