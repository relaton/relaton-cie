module RelatonCie
  module Util
    extend RelatonBib::Util

    def self.logger
      RelatonCie.configuration.logger
    end
  end
end
