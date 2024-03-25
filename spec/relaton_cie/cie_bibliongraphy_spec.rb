describe RelatonCie::CieBibliography do
  it ".search" do
    expect(RelatonCie::Scrapper).to receive(:scrape_page).with("CIE 001-1980").and_return :bib
    expect(described_class.search("CIE 001-1980")).to eq :bib
  end

  context ".get" do
    it "not found" do
      expect(described_class).to receive(:search).with("CIE 001-1980").and_return nil
      expect do
        expect(described_class.get("CIE 001-1980")).to be_nil
      end.to output(/\[relaton-cie\] INFO: \(CIE 001-1980\) Not found\./).to_stderr_from_any_process
    end

    it "found" do
      bib = double "bib", docidentifier: [double("id", id: "CIE 001-1980")]
      expect(described_class).to receive(:search).with("CIE 001-1980").and_return bib
      expect do
        expect(described_class.get("CIE 001-1980")).to be bib
      end.to output(include(
        "[relaton-cie] INFO: (CIE 001-1980) Fetching from Relaton repository ...",
        "[relaton-cie] INFO: (CIE 001-1980) Found: `CIE\s001-1980`",
      )).to_stderr_from_any_process
    end
  end
end
