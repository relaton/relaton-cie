RSpec.describe Relaton::Cie::Scrapper do
  # it "raise HTTP Request Timeout error" do
  #   exception_io = double "io"
  #   expect(exception_io).to receive(:status).and_return ["408", "Request Timeout"]
  #   expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
  #   expect do
  #     Relaton::Cie::Bibliography.get "CIE 001-1980"
  #   end.to raise_error Relaton::RequestError
  # end

  context ".scrape_page" do
    let(:agent) { instance_double Mechanize }
    let(:index) { double "index" }

    before do
      expect(index).to receive(:search).and_return [id: "CIE 001-1980", file: "cie-001-1980.yaml"]
      expect(Relaton::Index).to receive(:find_or_create).and_return index
      expect(Mechanize).to receive(:new).and_return agent
    end

    it "HTTP Not Found error" do
      resp = double "response", code: "404"
      expect(agent).to receive(:get).and_raise Mechanize::ResponseCodeError.new(resp, "404")
      expect(described_class.scrape_page("CIE 001-1980")).to be_nil
    end

    it "raise HTTP Request Timeout error" do
      expect(agent).to receive(:get).and_raise Timeout::Error
      expect do
        described_class.scrape_page "CIE 001-1980"
      end.to raise_error Relaton::RequestError
    end
  end
end
