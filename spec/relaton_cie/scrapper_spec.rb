RSpec.describe RelatonCie::Scrapper do
  before { RelatonCie.instance_variable_set :@configuration, nil }

  it "raise HTTP Request Timeout error" do
    exception_io = double "io"
    expect(exception_io).to receive(:status).and_return ["408", "Request Timeout"]
    expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
    expect do
      RelatonCie::CieBibliography.get "CIE 001-1980"
    end.to raise_error RelatonBib::RequestError
  end

  it "raise HTTP Not Found error" do
    exception_io = double "io"
    expect(exception_io).to receive(:status).and_return ["404", "Not Found"]
    expect(OpenURI).to receive(:open_uri).and_raise OpenURI::HTTPError.new "Not found", exception_io
    expect do
      expect(RelatonCie::CieBibliography.get("CIE 001-1980")).to be_nil
    end.to output(/no match found online for `CIE 001-1980`/).to_stderr
  end
end
