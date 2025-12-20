require "jing"

RSpec.describe Relaton::Cie do
  before do
    # Force to download index file
    allow_any_instance_of(Relaton::Index::Type).to receive(:actual?).and_return(false)
    allow_any_instance_of(Relaton::Index::FileIO).to receive(:check_file).and_return(nil)
  end

  it "has a version number" do
    expect(Relaton::Cie::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = Relaton::Cie.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end

  context "get CIE standard" do
    it "and return RelatonXML" do
      VCR.use_cassette "cie_001_1980" do
        bib = Relaton::Cie::Bibliography.get "CIE 001-1980"
        bibitem = bib.to_xml.gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        bibitem_file = "spec/fixtures/bibitem.xml"
        write_file bibitem_file, bibitem
        # expect(bibitem).to be_equivalent_to read_file bibitem_file

        bibdata = bib.to_xml(bibdata: true)
          .gsub(/(?<=<fetched>)\d{4}-\d{2}-\d{2}/, Date.today.to_s)
        bibdata_file = "spec/fixtures/bibdata.xml"
        write_file bibdata_file, bibdata
        # expect(bibdata).to be_equivalent_to read_file bibdata_file
        schema = Jing.new "grammars/relaton-cie-compile.rng"
        errors = schema.validate bibdata_file
        expect(errors).to eq []
      end
    end
  end
end
