module Relaton
  module Cie
    class Bibdata < Item
      model ItemData
      include Bib::BibdataShared
    end
  end
end
