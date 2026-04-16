module Relaton
  module Cie
    class Ext < Bib::Ext
      def get_schema_version = Relaton.schema_versions["relaton-model-cie"]
    end
  end
end
