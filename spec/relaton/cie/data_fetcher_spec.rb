# encoding: UTF-8

require "relaton/cie/data_fetcher"

RSpec.describe Relaton::Cie::DataFetcher do
  context "instance methods" do
    let(:hit) do
      Nokogiri::HTML(<<~HTML).at("li")
        <li data-product="2930375">
          <div class="cover product_image">
            <p class="notice version-notice">
                <span class="version powertip" data-powertiptarget="current_flag_content" title="This is the most recent version of this document."><i class="current-version ss-icon"></i>MOST RECENT</span>
            </p>
            <a href="https://store.accuristech.com/standards/cie-iso-8995-1-2025-en?product_id=2930375">
              <img src="//images.techstreet.com/coverart/3/7/5/2930375.jpg">      </a>
          </div><!-- .cover.product_image //-->
          <div class="product_detail">
            <h3>
              <a href="https://store.accuristech.com/standards/cie-iso-8995-1-2025-en?product_id=2930375">
                <span class="highlight">CIE</span> <span class="highlight">ISO</span> <span class="highlight">8995-1:2025(en)</span><span class="ss-icon">▹</span>
              </a>
            </h3>
            <h4>Light and lighting - Lighting of work places - Part 1: Indoor</h4>
            <p class="pub_date"><span>standard</span> by <span class="publisher_name">Commission Internationale de L'Eclairage</span>, 01/01/2025.
            </p>
            <p class="pub_date">
              <span>Languages: </span>
              English
            </p>
            <p class="pub_date">
              <span>Historical Editions:</span>
              <a href="https://store.accuristech.com/standards/cie-s-008-e-2001-iso-8995-1-2002-e?product_id=1529685">CIE S 008/E:2001 (ISO 8995-1:2002(E))</a>
            </p>
          </div><!-- .product_detail //-->
        </li>
      HTML
    end

    subject { described_class.new "data", "yaml" }

    context "#fetch" do
      let(:url) { "https://www.techstreet.com/cie/searches/31156444?page=1&per_page=100" }

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
        expect(subject.agent).to receive(:get).with(url).and_return result
        expect(subject).to receive(:fetch_doc).with("https://www.techstreet.com/cie/standards?page=2")
        allow(subject).to receive(:fetch_doc).with(no_args).and_call_original
        expect(subject.index).not_to receive(:save)
        subject.fetch
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
        expect(subject.agent).to receive(:get).with(url).and_return result
        expect(subject.index).to receive(:save)
        subject.fetch
      end
    end

    context "#parse_page" do
      let(:doc) { Nokogiri::HTML File.read("spec/fixtures/doc.html") }

      before do
        expect(subject).to receive(:time_req).and_yield
      end

      it do
        link = "https://store.accuristech.com/standards/cie-iso-8995-1-2025-en?product_id=2930375"
        expect(subject.agent).to receive(:get).with(link).and_return doc
        item = nil
        expect(subject).to receive(:write_file) { |i| item = i }
        subject.parse_page hit
        expect(item).to be_instance_of Relaton::Bib::ItemData
        expect(item.id).to eq "CIEISO899512025"
        expect(item.type).to eq "standard"
        expect(item.source.first).to be_instance_of Relaton::Bib::Uri
        expect(item.docnumber).to eq "8995-1:2025"
        expect(item.docidentifier.first).to be_instance_of Relaton::Bib::Docidentifier
        expect(item.title.first).to be_instance_of Relaton::Bib::Title
        expect(item.abstract.first).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
        expect(item.date.first).to be_instance_of Relaton::Bib::Date
        expect(item.edition).to be_instance_of Relaton::Bib::Edition
        expect(item.contributor.first).to be_instance_of Relaton::Bib::Contributor
        expect(item.relation.first).to be_instance_of Relaton::Bib::Relation
        expect(item.language).to eq "en"
        expect(item.script).to eq "Latn"
        expect(item.ext).to be_instance_of Relaton::Cie::Ext
        expect(item.ext.doctype).to be_instance_of Relaton::Bib::Doctype
        expect(item.ext.flavor).to eq "cie"
        expect(item.ext.schema_version).to eq Relaton.schema_versions["relaton-model-cie"]
      end

      it "raise error" do
        expect(subject.agent).to receive(:get).and_raise StandardError
        expect { subject.parse_page hit }.to output(
          /https:\/\/store\.accuristech\.com\/standards\/cie-iso-8995-1-2025-en\?product_id=2930375/
        ).to_stderr_from_any_process
      end
    end

    it "#fetch_link" do
      source = subject.fetch_source "https://www.techstreet.com/cie/standards/001-1980"
      expect(source).to be_instance_of Array
      expect(source.first).to be_instance_of Relaton::Bib::Uri
      expect(source.first.content.to_s).to eq "https://www.techstreet.com/cie/standards/001-1980"
      expect(source.first.type).to eq "src"
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
        expect(docid.first).to be_instance_of Relaton::Bib::Docidentifier
        expect(docid.first.content).to eq "CIE 001-1980"
        expect(docid.first.type).to eq "CIE"
        expect(docid.first.primary).to be true
        expect(docid.last.content).to eq "9783902842001"
        expect(docid.last.type).to eq "ISBN"
      end

      it "two codes" do
        doc = Nokogiri::HTML "<html><body></body></html>"
        expect(subject).to receive(:parse_code).with(:hit, doc).and_return ["CIE S 014-1/E:2006", "ISO 10527:2007"]
        docid = subject.fetch_docid :hit, doc
        expect(docid).to be_instance_of Array
        expect(docid.size).to eq 2
        expect(docid.first).to be_instance_of Relaton::Bib::Docidentifier
        expect(docid.first.content).to eq "CIE S 014-1/E:2006"
        expect(docid.first.type).to eq "CIE"
        expect(docid.first.primary).to be true
        expect(docid.last.content).to eq "ISO 10527:2007"
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
        expect(title[0]).to be_instance_of Relaton::Bib::Title
        expect(title.size).to eq 2
        expect(title.first).to be_instance_of Relaton::Bib::Title
        expect(title.first.content).to eq "Title"
        expect(title.first.type).to eq "title-main"
        expect(title.last).to be_instance_of Relaton::Bib::Title
        expect(title.last.content).to eq "Title"
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
        expect(title[0]).to be_instance_of Relaton::Bib::Title
        expect(title.size).to eq 2
        expect(title.first.content).to eq "Title"
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
        expect(abstract.first).to be_instance_of Relaton::Bib::LocalizedMarkedUpString
        expect(abstract.first.content).to eq "Description"
        expect(abstract.first.language).to eq "en"
        expect(abstract.first.script).to eq "Latn"
      end
    end

    context "#fetch_date" do
      shared_examples "fetch date" do |source, expected|
        it do
          doc = Nokogiri::HTML <<~HTML
            <html>
              <body>
                <div class="product-details__row">
                  <h3>Published:</h3>
                  <span>#{source}</span>
                </div>
              </body>
            </html>
          HTML
          date = subject.fetch_date doc
          expect(date).to be_instance_of Array
          expect(date.size).to eq 1
          expect(date.first).to be_instance_of Relaton::Bib::Date
          expect(date.first.type).to eq "published"
          expect(date.first.at.to_s).to eq expected
        end
      end

      it_behaves_like "fetch date", " 1992", "1992"
      it_behaves_like "fetch date", " 02/22/2023", "2023-02-22"
    end

    it "#fetch_edition" do
      doc = Nokogiri::HTML <<~HTML
        <html>
          <body>
            <div class="product-details__row">
              <h3>Edition:</h3>
              <span>1st</span>
            </div>
          </body>
        </html>
      HTML
      expect(subject.fetch_edition(doc).content).to eq "1"
    end

    context "#fetch_contributor" do
      it do
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
        expect(contribs.first).to be_instance_of Relaton::Bib::Contributor
        expect(contribs.first.person).to be_instance_of Relaton::Bib::Person
        expect(contribs.first.person.name.surname.content).to eq "Ruggaber"
        expect(contribs.first.person.name.forename[0].initial).to eq "B"
        expect(contribs.first.role.first.type).to eq "author"
        expect(contribs.last.organization).to be_instance_of Relaton::Bib::Organization
        expect(contribs.last.organization.name.first.content).to eq "Commission Internationale de L'Eclairage"
        expect(contribs.last.role.first.type).to eq "publisher"
      end

      it do
        doc = Nokogiri::HTML <<~HTML
          <html>
            <body>
              <hgroup>
                <p>Vali, K.; Au-Yeung, W-T. M.; Kaye, J.; Pierson, C.</p>
              </hgroup>
            </body>
          </html>
        HTML
        contribs = subject.fetch_contributor doc
        expect(contribs).to be_instance_of Array
        expect(contribs.size).to eq 6
      end
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
      expect(doctype).to be_instance_of Relaton::Bib::Doctype
      expect(doctype.content).to eq "document"
    end

    context "#parse_code" do
      it "one code" do
        expect(subject).to receive(:primary_code).with("CIE ISO 8995-1:2025(en)", nil).and_return "CIE ISO 8995-1:2025(en)"
        code = subject.parse_code hit
        expect(code).to be_instance_of Array
        expect(code.size).to eq 2
        expect(code.first).to eq "CIE ISO 8995-1:2025(en)"
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
      expect(subject.fetch_docnumber(hit)).to eq "8995-1:2025"
    end

    it "#index" do
      expect(subject.index).to be_instance_of Relaton::Index::Type
    end

    context "#write_file" do
      let(:bib) do
        docid = double "docid", content: "CIE 001-1980", type: "CIE", primary: true
        source = double "source", type: "src", content: "https://www.techstreet.com/cie/standards/001-1980"
        double "bibliographic item", docidentifier: [docid], source: [source]
      end

      before do
        expect(subject).to receive(:content).with(bib).and_return "content"
        expect(subject.index).to receive(:add_or_update).with("CIE 001-1980", "data/CIE_001_1980.yaml")
        expect(File).to receive(:write).with("data/CIE_001_1980.yaml", "content", encoding: "UTF-8")
      end

      it do
        subject.write_file bib
        expect(subject.instance_variable_get(:@files)).to include "data/CIE_001_1980.yaml"
      end

      it "file exists" do
        subject.instance_variable_get(:@files) << "data/CIE_001_1980.yaml"
        expect { subject.write_file bib }.to output(/File data\/CIE_001_1980.yaml exists/).to_stderr_from_any_process
      end
    end

    context "#content" do
      let(:bib) { Relaton::Bib::ItemData.new }

      it "xml" do
        subject.instance_variable_set :@format, "xml"
        expect(subject.content(bib)).to include "<bibdata schema-version="
      end

      it "yaml" do
        expect(subject.content(bib)).to include "---\nschema_version:"
      end

      it "bibxml" do
        subject.instance_variable_set :@format, "bibxml"
        expect(bib).to receive(:to_bibxml).and_return "bibxml"
        expect(subject.content(bib)).to eq "bibxml"
      end
    end

    context "#time_req" do
      it "sleep" do
        expect(subject).to receive(:sleep).with(4)
        subject.time_req { :result }
        result = subject.time_req { :result }
        expect(result).to eq :result
      end

      it "retry" do
        block = spy "block"
        expect(block).to receive(:call).and_raise Socket::ResolutionError
        expect(block).to receive(:call).and_return :result
        result = subject.time_req { block.call }
        expect(result).to eq :result
      end

      it "raise error" do
        expect do
          subject.time_req { raise Socket::ResolutionError }
        end.to raise_error(Socket::ResolutionError)
      end
    end
  end
end
