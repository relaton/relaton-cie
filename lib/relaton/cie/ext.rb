module Relaton
  module Cie
    class Ext < Bib::Ext
      attribute :schema_version, method: :get_shema_version

      def get_shema_version
        Relaton.schema_versions["relaton-model-cie"]
      end
    end
  end
end
