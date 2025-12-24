require "relaton/cie/processor"
require "relaton/cie/data_fetcher"

describe Relaton::Cie::Processor do
  it "#intialize" do
    expect(subject.instance_variable_get(:@short)).to eq :relaton_cie
    expect(subject.instance_variable_get(:@prefix)).to eq "CIE"
    expect(subject.instance_variable_get(:@defaultprefix)).to eq %r{^CIE(-|\s)}
    expect(subject.instance_variable_get(:@idtype)).to eq "CIE"
    expect(subject.instance_variable_get(:@datasets)).to eq %w[cie-techstreet]
  end

  it "#get" do
    expect(Relaton::Cie::Bibliography).to receive(:get).with("CIE 018", "2019", {})
    subject.get "CIE 018", "2019", {}
  end

  it "#fetch_data" do
    expect(Relaton::Cie::DataFetcher).to receive(:fetch).with(output: "output", format: "xml")
    subject.fetch_data "cie-techstreet", output: "output", format: "xml"
  end

  it "#from_xml" do
    expect(Relaton::Cie::Item).to receive(:from_xml).with("<xml></xml>")
    subject.from_xml "<xml></xml>"
  end

  it "#from_yaml" do
    expect(Relaton::Cie::Item).to receive(:from_yaml).with("---\nkey: value\n")
    subject.from_yaml "---\nkey: value\n"
  end

  it "#grammar_hash" do
    expect(subject.grammar_hash).to be_a String
  end

  it "#remove_index_file" do
    index = instance_double Relaton::Index::Type
    expect(Relaton::Index).to receive(:find_or_create)
      .with(:cie, url: true, file: Relaton::Cie::Scrapper::INDEX_FILE).and_return index
    expect(index).to receive(:remove_file)
    subject.remove_index_file
  end
end
