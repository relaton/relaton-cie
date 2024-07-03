RSpec.describe RelatonCie::Scrapper do
  it "raise HTTP Request Timeout error" do
    exception_io = double "io"
    expect(exception_io).to receive(:status).and_return ["408", "Request Timeout"]
    expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
    expect do
      RelatonCie::CieBibliography.get "CIE 001-1980"
    end.to raise_error RelatonBib::RequestError
  end

  context ".scrape_page" do
    let(:index) { double "index" }
    let(:exception_io) { double "io" }

    before do
      expect(index).to receive(:search).and_return [id: "CIE 001-1980", file: "cie-001-1980.yaml"]
      expect(Relaton::Index).to receive(:find_or_create).and_return index
    end

    it "HTTP Not Found error" do
      expect(exception_io).to receive(:status).and_return ["404", "Not Found"]
      expect(described_class).to receive(:parse_page).and_raise OpenURI::HTTPError.new "Not found", exception_io
      expect(described_class.scrape_page("CIE 001-1980")).to be_nil
    end

    it "raise HTTP Request Timeout error" do
      expect(exception_io).to receive(:status).and_return ["408", "Timeout"]
      expect(described_class).to receive(:parse_page).and_raise OpenURI::HTTPError.new "Timeout", exception_io
      expect do
        described_class.scrape_page "CIE 001-1980"
      end.to raise_error RelatonBib::RequestError
    end
  end
end
