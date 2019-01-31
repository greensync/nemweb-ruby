require 'csv'
require 'nemweb/version'
require 'net/http'
require 'nokogiri'
require 'open-uri'
require 'zip'

class Nemweb

  # Public: Load and parse data.
  #
  # source - a data file or URI
  #
  # Yields records, as Hash objects.
  #
  def parse(source)
    fetch(source) do |stream|
      headers = nil
      CSV.parse(stream) do |row|
        case row[0]
        when "I"
          headers = row[4..-1]
        when "D"
          record = DataRecord.new(
            row[1], row[2], Integer(row[3]),
            Hash[headers.zip(row[4..-1])]
          )
          yield record
        end
      end
    end
  end

  # Public: Get the files in a NEM data directory.
  #
  # dir - subdirectory of http://nemweb.com.au/Reports/Current/
  #
  def list_files(dir)
    dir_uri = URI("http://nemweb.com.au/Reports/Current/") + dir
    doc = Nokogiri::HTML.parse(dir_uri.read)
    doc.css('a').map { |link| link["href"] }.grep(/\.zip$/).map do |href|
      DataFile.new(dir_uri + href, self)
    end
  end

  class DataFile < Struct.new(:uri)

    def initialize(uri, nemweb)
      super(uri)
      @nemweb = nemweb
    end

    def name
      File.basename(uri.path)
    end

    def period
      name.scan(/_(\d{4,})/).first.first
    end

    def parse(&block)
      @nemweb.parse(uri, &block)
    end

  end

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

  # Open a data source, and yield a stream.
  #
  # source - a data file or URI
  #
  # If the data source is a ZIP file, extract the first entry.
  #
  def fetch(source, &block)
    if source.respond_to?(:close)
      yield source
      return
    end
    stream = open(source)
    if source.to_s =~ /zip\Z/i
      Zip::File.open_buffer(stream) do |zipfile|
        yield zipfile.entries.first.get_input_stream
      end
    else
      yield stream
    end
  ensure
    stream.close if stream.respond_to?(:close)
  end

end
