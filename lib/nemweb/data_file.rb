module Nemweb

  class DataFile < Struct.new(:uri)

    def initialize(uri, client)
      super(uri)
      @client = client
    end

    def name
      File.basename(uri.path)
    end

    def period
      name.scan(/_(\d{4,})/).first.first
    end

    def parse(&block)
      @client.parse(uri, &block)
    end

  end

end
