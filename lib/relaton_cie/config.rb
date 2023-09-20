module RelatonCie
  module Config
    include RelatonBib::Config
  end
  extend Config

  class Configuration < RelatonBib::Configuration
    PROGNAME = "relaton-cie".freeze
  end
end
