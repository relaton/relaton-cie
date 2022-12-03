RSpec.describe "Fetching data" do
  it "create DataFetcher instance" do
    expect(FileUtils).to receive(:mkdir).with "data"
    instance = double "DataFetcher instance"
    expect(instance).to receive(:fetch).with RelatonCie::DataFetcher::URL
    expect(RelatonCie::DataFetcher).to receive(:new).with("data", "yaml").and_return instance
    RelatonCie::DataFetcher.fetch
  end

  it "get index page" do
    agent = double "Mechanize instance"
    # expect(agent).to receive(:get).with(RelatonCie::DataFetcher::URL).and_return []
    expect(Mechanize).to receive(:new).and_return agent
    instance = RelatonCie::DataFetcher.new "data", "yaml"
    expect(instance.instance_variable_get(:@agent)).to be agent
    expect(instance.instance_variable_get(:@output)).to eq "data"
    expect(instance.instance_variable_get(:@format)).to eq "yaml"
  end

  it "fetch documents" do
    VCR.use_cassette "fetch_data" do
      url = RelatonCie::DataFetcher::URL.sub("per_page=100", "per_page=5")
      df = RelatonCie::DataFetcher.new "data", "yaml"
      ag = df.instance_variable_get :@agent
      ag_get = ag.method :get
      allow(ag).to receive(:get) do |uri|
        res = ag_get.call uri
        if uri.include?("page=2")
          allow(res).to receive(:at).with('//a[@class="next_page"]').and_return nil
        end
        res
      end
      expect(File).to receive(:write).with(kind_of(String), kind_of(String), encoding: "UTF-8").exactly(10).times
      df.fetch url
    end
  end

  it "fetch documents with alternate docids" do
    url = RelatonCie::DataFetcher::URL.sub("per_page=100", "per_page=5")
    url.sub!("page=1", "page=53")
    df = RelatonCie::DataFetcher.new "data", "yaml"
    ag = df.instance_variable_get :@agent
    ag_get = ag.method :get
    allow(ag).to receive(:get) do |uri|
      res = ag_get.call uri
      allow(res).to receive(:at).and_call_original
      allow(res).to receive(:at).with('//a[@class="next_page"]').and_return nil
      res
    end
    expect(File).to receive(:write).with(kind_of(String), kind_of(String), encoding: "UTF-8").exactly(5).times
    VCR.use_cassette "fetch_data_alt_docid" do
      df.fetch url
    end
  end

  it "fetch parse relations" do
    df = RelatonCie::DataFetcher.new "data", "yaml"
    doc = Nokogiri::HTML <<~HTML
      <html>
        <body>
          <section class="history">
            <ol>
              <li class="selected-product"><a><h3>CIE 001-1980</h3></a></li>
              <li>
                <a href="/cie/standards/001-1981">
                  <h3>CIE 001-1981</h3>
                  <p>
                    <time datetime="1992-01-01 00:00:00 +0000">January 1992</time>
                    <span class="title">Title</span>
                  </p>
                  <div><ul><li><i class="historical">Historical Version</i></li></ul></div>
                </a>
              </li>
            </ol>
          </section>
        </body>
      </html>
    HTML
    rels = df.fetch_relation doc
    expect(rels.size).to eq 1
    expect(rels.first[:type]).to eq "updates"
    expect(rels.first[:bibitem].docidentifier.first.id).to eq "CIE 001-1981"
    expect(rels.first[:bibitem].docidentifier.first.type).to eq "CIE"
    expect(rels.first[:bibitem].title.first.title.content).to eq "Title"
    expect(rels.first[:bibitem].date.first.on).to eq "1992-01-01"
    expect(rels.first[:bibitem].link.first.content.to_s).to eq "https://www.techstreet.com/cie/standards/001-1981"
  end

  it "raise error" do
    df = RelatonCie::DataFetcher.new "data", "yaml"
    ag = df.instance_variable_get :@agent
    # allow(ag).to receive(:get).and_call_original
    hit = double "hit"
    allow(hit).to receive(:at).and_return({ href: "/url" })
    allow(ag).to receive(:get).and_raise StandardError
    expect { df.parse_page(hit) }.to output(/Document: https:\/\/www\.techstreet\.com\/url/).to_stderr
  end
end
