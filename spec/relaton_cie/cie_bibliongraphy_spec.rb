describe RelatonCie::CieBibliography do
  before { RelatonCie.instance_variable_set :@configuration, nil }

  it ".search" do
    expect(RelatonCie::Scrapper).to receive(:scrape_page).with("CIE 001-1980").and_return :bib
    expect(described_class.search("CIE 001-1980")).to eq :bib
  end

  context ".get" do
    it "not found" do
      expect(described_class).to receive(:search).with("CIE 001-1980").and_return nil
      expect do
        expect(described_class.get("CIE 001-1980")).to be_nil
      end.to output(/\[relaton-cie\] \(CIE 001-1980\) Not found\./).to_stderr
    end

    it "found" do
      bib = double "bib", docidentifier: [double("id", id: "CIE 001-1980")]
      expect(described_class).to receive(:search).with("CIE 001-1980").and_return bib
      expect do
        expect(described_class.get("CIE 001-1980")).to be bib
      end.to output(%r{
        \[relaton-cie\]\s\(CIE\s001-1980\)\sFetching\sfrom\sRelaton\srepository\s\.\.\.\n
        \[relaton-cie\]\s\(CIE\s001-1980\)\sFound:\s`CIE\s001-1980`
      }x).to_stderr
    end
  end
end
