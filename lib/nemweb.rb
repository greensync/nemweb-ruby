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

  CURRENT_REPORTS = URI("http://nemweb.com.au/Reports/Current/").freeze

  # Public: Get the files in a NEM data directory.
  #
  # dir - subdirectory of http://nemweb.com.au/Reports/Current/
  #
  def list_files(dir)
    dir_uri = CURRENT_REPORTS + dir
    doc = Nokogiri::HTML.parse(dir_uri.read)
    doc.css('a').map { |link| link["href"] }.grep(/\.zip$/).map do |href|
      DataFile.new(dir_uri + href, self)
    end
  end


  # Public: List available NEM data directories
  #
  def dirs(root_uri = CURRENT_REPORTS)
    doc = Nokogiri::HTML.parse(root_uri.read)
    doc.css('a').map { |link| root_uri + link["href"] }
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
  def fetch(source)
    open(source) do |stream|
      if source.to_s =~ /zip\Z/i
        Zip::File.open_buffer(stream) do |zipfile|
          zipfile.entries.each do |entry|
            yield entry.get_input_stream, entry.name
          end
        end
      else
        yield stream, source
      end
    end
  end

end
