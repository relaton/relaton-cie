module Relaton
  module Cie
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end
