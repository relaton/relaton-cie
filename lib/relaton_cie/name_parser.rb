module RelatonCie
  class NameParser < Parslet::Parser
    root(:name)
    rule(:name) { name_part.as(:name_part) >> (comma >> name_part).repeat }
  end
end
