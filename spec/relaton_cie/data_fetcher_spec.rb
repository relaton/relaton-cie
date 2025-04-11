# encoding: UTF-8

RSpec.describe RelatonCie::DataFetcher do
  it "initialize" do
    df = described_class.new "data", "bibxml"
    expect(df.instance_variable_get(:@output)).to eq "data"
    expect(df.instance_variable_get(:@format)).to eq "bibxml"
    expect(df.instance_variable_get(:@ext)).to eq "xml"
    expect(df.instance_variable_get(:@files)).to eq []
  end

  it "create DataFetcher instance" do
    expect(FileUtils).to receive(:mkdir_p).with "dir"
    df = double "DataFetcher instance"
    expect(df).to receive(:fetch).with RelatonCie::DataFetcher::URL
    expect(described_class).to receive(:new).with("dir", "bibxml").and_return df
    described_class.fetch output: "dir", format: "bibxml"
  end

  context "instance methods" do
    let(:hit) do
      Nokogiri::HTML(<<~HTML).at("li")
        <li data-product="CIE 001-1980">
          <h3><a href="https://www.techstreet.com/cie/standards/001-1980">CIE 001-1980</a></h3>
        </li>
      HTML
    end

    subject { described_class.new "data", "yaml" }

    context "#fetch" do
      before do
        expect(subject).to receive(:time_req).and_yield
        expect(subject).to receive(:parse_page).with(kind_of(Nokogiri::XML::Element))
      end

      it "next page" do
        result = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <ol>
                <li data-product="CIE 001-1980"><h3><a href="/cie/standards/001-1980">CIE 001-1980</a></h3></li>
              </ol>
              <a class="next_page" href="/cie/standards?page=2">Next</a>
            </body>
          </html>
        HTML
        expect(subject.agent).to receive(:get).with(:url).and_return result
        expect(subject).to receive(:fetch).with("https://www.techstreet.com/cie/standards?page=2")
        allow(subject).to receive(:fetch).with(:url).and_call_original
        expect(subject.index).not_to receive(:save)
        subject.fetch :url
      end

      it "last page" do
        result = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <ol>
                <li data-product="CIE 001-1980"><h3><a href="/cie/standards/001-1980">CIE 001-1980</a></h3></li>
              </ol>
            </body>
          </html>
        HTML
        expect(subject.agent).to receive(:get).with(:url).and_return result
        expect(subject.index).to receive(:save)
        subject.fetch :url
      end
    end

    context "#parse_page" do
      before do
        expect(subject).to receive(:time_req).and_yield
      end

      it do
        link = "https://www.techstreet.com/cie/standards/001-1980"
        expect(subject.agent).to receive(:get).with(link).and_return :doc
        expect(subject).to receive(:fetch_link).with(link).and_return :link
        expect(subject).to receive(:fetch_docnumber).with(hit).and_return :docnumber
        expect(subject).to receive(:fetch_docid).with(hit, :doc).and_return :docid
        expect(subject).to receive(:fetch_title).with(:doc).and_return :title
        expect(subject).to receive(:fetch_abstract).with(:doc).and_return :abstract
        expect(subject).to receive(:fetch_date).with(:doc).and_return :date
        expect(subject).to receive(:fetch_edition).with(:doc).and_return :edition
        expect(subject).to receive(:fetch_contributor).with(:doc).and_return :contributor
        expect(subject).to receive(:fetch_relation).with(:doc).and_return :relation
        expect(subject).to receive(:fetch_doctype).with(no_args).and_return :doctype
        expect(RelatonCie::BibliographicItem).to receive(:new).with(
          type: "standard", link: :link, docnumber: :docnumber, docid: :docid,
          title: :title, abstract: :abstract, date: :date, edition: :edition,
          contributor: :contributor, relation: :relation, language: ["en"],
          script: ["Latn"], doctype: :doctype
        ).and_return :item
        expect(subject).to receive(:write_file).with(:item)
        subject.parse_page hit
      end

      it "raise error" do
        expect(subject.agent).to receive(:get).and_raise StandardError
        expect { subject.parse_page hit }.to output(
          /Document: https:\/\/www\.techstreet\.com\/cie\/standards\/001-1980/
        ).to_stderr_from_any_process
      end
    end

    it "#fetch_link" do
      link = subject.fetch_link "https://www.techstreet.com/cie/standards/001-1980"
      expect(link).to be_instance_of Array
      expect(link.first).to be_instance_of RelatonBib::TypedUri
      expect(link.first.content.to_s).to eq "https://www.techstreet.com/cie/standards/001-1980"
      expect(link.first.type).to eq "src"
    end

    context "#fetch_docid" do
      it "one code & ISBN" do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <dt>ISBN(s):</dt>
              <dd>9783902842001</dd>
            </body>
          </html>
        HTML
        expect(subject).to receive(:parse_code).with(:hit, doc).and_return ["CIE 001-1980", nil]
        docid = subject.fetch_docid :hit, doc
        expect(docid).to be_instance_of Array
        expect(docid.size).to eq 2
        expect(docid.first).to be_instance_of RelatonBib::DocumentIdentifier
        expect(docid.first.id).to eq "CIE 001-1980"
        expect(docid.first.type).to eq "CIE"
        expect(docid.first.primary).to be true
        expect(docid.last.id).to eq "9783902842001"
        expect(docid.last.type).to eq "ISBN"
      end

      it "two codes" do
        doc = Nokogiri::HTML "<html><body></body></html>"
        expect(subject).to receive(:parse_code).with(:hit, doc).and_return ["CIE S 014-1/E:2006", "ISO 10527:2007"]
        docid = subject.fetch_docid :hit, doc
        expect(docid).to be_instance_of Array
        expect(docid.size).to eq 2
        expect(docid.first).to be_instance_of RelatonBib::DocumentIdentifier
        expect(docid.first.id).to eq "CIE S 014-1/E:2006"
        expect(docid.first.type).to eq "CIE"
        expect(docid.first.primary).to be true
        expect(docid.last.id).to eq "ISO 10527:2007"
        expect(docid.last.type).to eq "ISO"
      end
    end

    context "#fetch_title" do
      it "h1" do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <hgroup><h1>Title</h1></hgroup>
            </body>
          </html>
        HTML
        title = subject.fetch_title doc
        expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
        expect(title.size).to eq 2
        expect(title.first).to be_instance_of RelatonBib::TypedTitleString
        expect(title.first.title.content).to eq "Title"
        expect(title.first.type).to eq "title-main"
        expect(title.last).to be_instance_of RelatonBib::TypedTitleString
        expect(title.last.title.content).to eq "Title"
        expect(title.last.type).to eq "main"
      end

      it "h2" do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <hgroup><h2>Title</h2></hgroup>
            </body>
          </html>
        HTML
        title = subject.fetch_title doc
        expect(title).to be_instance_of RelatonBib::TypedTitleStringCollection
        expect(title.size).to eq 2
        expect(title.first.title.content).to eq "Title"
      end

      it "empty" do
        doc = Nokogiri::HTML "<html><body></body></html>"
        title = subject.fetch_title doc
        expect(title).to eq []
      end
    end

    context "#fetch_abstract" do
      it do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <div class="description"> Description </div>
            </body>
          </html>
        HTML
        abstract = subject.fetch_abstract doc
        expect(abstract).to be_instance_of Array
        expect(abstract.size).to eq 1
        expect(abstract.first).to be_instance_of RelatonBib::FormattedString
        expect(abstract.first.content).to eq "Description"
        expect(abstract.first.language).to eq ["en"]
        expect(abstract.first.script).to eq ["Latn"]
      end
    end

    context "#fetch_date" do
      shared_examples "fetch date" do |source, expected|
        it do
          doc = Nokogiri::HTML <<~HTML
            <html>
              <body>
                <dt>Published:</dt>
                <dd>#{source}</dd>
              </body>
            </html>
          HTML
          date = subject.fetch_date doc
          expect(date).to be_instance_of Array
          expect(date.size).to eq 1
          expect(date.first).to be_instance_of RelatonBib::BibliographicDate
          expect(date.first.type).to eq "published"
          expect(date.first.on).to eq expected
        end
      end

      it_behaves_like "fetch date", " 1992", "1992"
      it_behaves_like "fetch date", " 02/22/2023", "2023-02-22"
    end

    it "#fetch_edition" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <dt>Edition:</dt>
            <dd>1st</dd>
          </body>
        </html>
      HTML
      expect(subject.fetch_edition(doc)).to eq "1"
    end

    it "#fetch_contributor" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <hgroup>
              <p class="pub_date">Published: 1992</p>
              <p>Ruggaber, B., Vollrath, T., Krüger, U., Blattner, P. and Gerloff, T.</p>
            </hgroup>
          </body>
        </html>
      HTML
      contribs = subject.fetch_contributor doc
      expect(contribs).to be_instance_of Array
      expect(contribs.size).to eq 6
      expect(contribs.first).to be_instance_of Hash
      expect(contribs.first[:entity]).to be_instance_of RelatonBib::Person
      expect(contribs.first[:entity].name.surname.content).to eq "Ruggaber"
      expect(contribs.first[:entity].name.forename[0].initial).to eq "B"
      expect(contribs.first[:role].first[:type]).to eq "author"
      expect(contribs.last[:entity]).to be_instance_of RelatonBib::Organization
      expect(contribs.last[:entity].name.first.content).to eq "Commission Internationale de L'Eclairage"
      expect(contribs.last[:role].first[:type]).to eq "publisher"
    end

    it "#fetch_relation" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <section class="history">
              <ol>
                <li class="selected-product"><a><h3>CIE 001-1980</h3></a></li>
                <li><a href="/cie/standards/001-1981">
                  <h3>CIE 001-1981</h3>
                  <p><time datetime="1992-01-01 00:00:00 +0000">January 1992</time>
                  <p><span class="title">Title</span></p>
                </a></li>
              </ol>
            </section>
          </body>
        </html>
      HTML
      relation = subject.fetch_relation doc
      expect(relation).to be_instance_of Array
      expect(relation.size).to eq 1
    end

    it "#fetch_doctype" do
      doctype = subject.fetch_doctype
      expect(doctype).to be_instance_of RelatonBib::DocumentType
      expect(doctype.type).to eq "document"
    end

    context "#parse_code" do
      it "one code" do
        expect(subject).to receive(:primary_code).with("CIE 001-1980", nil).and_return "CIE 001-1980"
        code = subject.parse_code hit
        expect(code).to be_instance_of Array
        expect(code.size).to eq 2
        expect(code.first).to eq "CIE 001-1980"
        expect(code.last).to be_nil
      end

      it "two codes" do
        hit = Nokogiri::HTML(<<~HTML).at("li")
          <li data-product="CIE S 006.1/E-1998 (ISO 16508:1999)">
            <h3><a href="/cie/standards/S-014-1-E-2006">CIE S 006.1/E-1998 (ISO 16508:1999)</a></h3>
          </li>
        HTML
        expect(subject).to receive(:primary_code).with("CIE S 006.1/E-1998", nil).and_return "CIE S 006.1/E-1998"
        code = subject.parse_code hit
        expect(code).to be_instance_of Array
        expect(code.size).to eq 2
        expect(code.first).to eq "CIE S 006.1/E-1998"
        expect(code.last).to eq "ISO 16508:1999"
      end
    end

    context "#primary_code" do
      it "one code" do
        expect(subject).to receive(:parse_cie_code).with("CIE S 006.1/E-1998 ", nil, nil).and_return "CIE S 006.1/E-1998"
        expect(subject.primary_code("CIE S 006.1/E-1998 (ISO 16508:1999)")).to eq "CIE S 006.1/E-1998"
      end

      it "code from doc" do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <dl>
                <dt>Product Code(s):</dt>
                <dd> x043-PP09, x043-PP09, x043-PP09</dd>
              </dl>
            </body>
          </html>
        HTML
        expect(subject.primary_code("", doc)).to eq "CIE x043-PP09"
      end

      it "code from braces" do
        expect(subject.primary_code("PERCEPTION OF ILLUMINATION WHITENESS (OP01, PAGES 1-7)")).to eq "CIE OP01 PAGES 1-7"
      end
    end

    context "#parse_cie_code" do
      it do
        expect(subject.parse_cie_code("CIE S 006.1/E-1998", nil)).to eq "CIE S 006.1/E-1998"
      end

      it "with addendum" do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <hgroup>
                <h2>Proceedings of CIE Centenary Conference "Towards a New Century of Light" Paris, France, 15-16 April 2013, Includes Addendum 1</h2>
              </hgroup>
            </body>
          </html>
        HTML
        expect(subject.parse_cie_code("CIE X038:2013", nil, doc)).to eq "CIE X038:2013 Add 1"
      end
    end

    it "#fetch_docnumber" do
      expect(subject.fetch_docnumber(hit)).to eq "001-1980"
    end

    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
    end

    context "#write_file" do
      let(:bib) do
        docid = double "docid", id: "CIE 001-1980", type: "CIE", primary: true
        link = double "link", type: "src", content: "https://www.techstreet.com/cie/standards/001-1980"
        double "bibliographic item", docidentifier: [docid], link: [link]
      end

      before do
        expect(subject).to receive(:content).with(bib).and_return "content"
        expect(subject.index).to receive(:add_or_update).with("CIE 001-1980", "data/CIE_001_1980.yaml")
        expect(File).to receive(:write).with("data/CIE_001_1980.yaml", "content", encoding: "UTF-8")
      end

      it do
        subject.write_file bib
        expect(subject.instance_variable_get(:@files)).to eq ["data/CIE_001_1980.yaml"]
      end

      it "file exists" do
        subject.instance_variable_set :@files, ["data/CIE_001_1980.yaml"]
        expect { subject.write_file bib }.to output(/File data\/CIE_001_1980.yaml exists/).to_stderr_from_any_process
      end
    end

    context "#content" do
      let(:bib) { double "bibliographic item" }

      it "xml" do
        subject.instance_variable_set :@format, "xml"
        expect(bib).to receive(:to_xml).with(bibdata: true).and_return "xml"
        expect(subject.content(bib)).to eq "xml"
      end

      it "yaml" do
        expect(bib).to receive(:to_hash).and_return "hash"
        expect(subject.content(bib)).to eq "--- hash\n"
      end

      it "bibxml" do
        subject.instance_variable_set :@format, "bibxml"
        expect(bib).to receive(:to_bibxml).and_return "bibxml"
        expect(subject.content(bib)).to eq "bibxml"
      end
    end

    context "#time_req" do
      it "reduced sleep" do
        expect(Time).to receive(:now).and_return 1, 2
        expect(subject).to receive(:sleep).with(3)
        result = subject.time_req { :result }
        expect(result).to eq :result
      end

      it "sleep" do
        expect(Time).to receive(:now).and_return 1, 1
        expect(subject).to receive(:sleep).with(4)
        subject.time_req { :result }
      end
    end
  end

  # it "create DataFetcher instance" do
  #   expect(FileUtils).to receive(:mkdir).with "data"
  #   instance = double "DataFetcher instance"
  #   expect(instance).to receive(:fetch).with RelatonCie::DataFetcher::URL
  #   expect(RelatonCie::DataFetcher).to receive(:new).with("data", "yaml").and_return instance
  #   RelatonCie::DataFetcher.fetch
  # end

  # it "get index page" do
  #   agent = double "Mechanize instance"
  #   # expect(agent).to receive(:get).with(RelatonCie::DataFetcher::URL).and_return []
  #   expect(Mechanize).to receive(:new).and_return agent
  #   instance = RelatonCie::DataFetcher.new "data", "yaml"
  #   expect(instance.instance_variable_get(:@agent)).to be agent
  #   expect(instance.instance_variable_get(:@output)).to eq "data"
  #   expect(instance.instance_variable_get(:@format)).to eq "yaml"
  # end

  # it "fetch documents" do
  #   VCR.use_cassette "fetch_data" do
  #     url = RelatonCie::DataFetcher::URL.sub("per_page=100", "per_page=5")
  #     df = RelatonCie::DataFetcher.new "data", "yaml"
  #     ag = df.instance_variable_get :@agent
  #     ag_get = ag.method :get
  #     allow(ag).to receive(:get) do |uri|
  #       res = ag_get.call uri
  #       if uri.include?("page=2")
  #         allow(res).to receive(:at).with('//a[@class="next_page"]').and_return nil
  #       end
  #       res
  #     end
  #     expect(File).to receive(:write).with(kind_of(String), kind_of(String), encoding: "UTF-8").exactly(10).times
  #     df.fetch url
  #   end
  # end

  # it "fetch documents with alternate docids" do
  #   url = RelatonCie::DataFetcher::URL.sub("per_page=100", "per_page=5")
  #   url.sub!("page=1", "page=53")
  #   df = RelatonCie::DataFetcher.new "data", "yaml"
  #   ag = df.instance_variable_get :@agent
  #   ag_get = ag.method :get
  #   allow(ag).to receive(:get) do |uri|
  #     res = ag_get.call uri
  #     allow(res).to receive(:at).and_call_original
  #     allow(res).to receive(:at).with('//a[@class="next_page"]').and_return nil
  #     res
  #   end
  #   expect(File).to receive(:write).with(kind_of(String), kind_of(String), encoding: "UTF-8").exactly(5).times
  #   VCR.use_cassette "fetch_data_alt_docid" do
  #     df.fetch url
  #   end
  # end

  # it "fetch parse relations" do
  #   df = RelatonCie::DataFetcher.new "data", "yaml"
  #   doc = Nokogiri::HTML <<~HTML
  #     <html>
  #       <body>
  #         <section class="history">
  #           <ol>
  #             <li class="selected-product"><a><h3>CIE 001-1980</h3></a></li>
  #             <li>
  #               <a href="/cie/standards/001-1981">
  #                 <h3>CIE 001-1981</h3>
  #                 <p>
  #                   <time datetime="1992-01-01 00:00:00 +0000">January 1992</time>
  #                   <span class="title">Title</span>
  #                 </p>
  #                 <div><ul><li><i class="historical">Historical Version</i></li></ul></div>
  #               </a>
  #             </li>
  #           </ol>
  #         </section>
  #       </body>
  #     </html>
  #   HTML
  #   rels = df.fetch_relation doc
  #   expect(rels.size).to eq 1
  #   expect(rels.first[:type]).to eq "updates"
  #   expect(rels.first[:bibitem].docidentifier.first.id).to eq "CIE 001-1981"
  #   expect(rels.first[:bibitem].docidentifier.first.type).to eq "CIE"
  #   expect(rels.first[:bibitem].title.first.title.content).to eq "Title"
  #   expect(rels.first[:bibitem].date.first.on).to eq "1992-01-01"
  #   expect(rels.first[:bibitem].link.first.content.to_s).to eq "https://www.techstreet.com/cie/standards/001-1981"
  # end

  # it "raise error" do
  #   df = RelatonCie::DataFetcher.new "data", "yaml"
  #   ag = df.instance_variable_get :@agent
  #   # allow(ag).to receive(:get).and_call_original
  #   hit = double "hit"
  #   allow(hit).to receive(:at).and_return({ href: "/url" })
  #   allow(ag).to receive(:get).and_raise StandardError
  #   expect { df.parse_page(hit) }.to output(/Document: https:\/\/www\.techstreet\.com\/url/).to_stderr
  # end
end
