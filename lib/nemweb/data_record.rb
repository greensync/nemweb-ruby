module Nemweb

  class DataRecord < Struct.new(:type, :subtype, :version, :data)

    def to_h
      {
        "type" => type,
        "subtype" => subtype,
        "version" => version,
        "data" => data
      }
    end

  end

end
