module RelatonCie
  class BibliographicItem < RelatonBib::BibliographicItem
    def ext_schema
      @ext_schema ||= schema_versions["relaton-model-cie"]
    end
  end
end
