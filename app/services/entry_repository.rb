# Persists SituationEntry data to a single JSON file on the user's desktop
# (spec D6, contracts/storage-file.md). The only component that touches the
# filesystem: all writes are atomic (temp file + rename), and the app never
# overwrites a file it could not read.
class EntryRepository
  class StorageError < StandardError; end

  FILE_FORMAT_VERSION = 1

  class << self
    def default_path
      ENV["SITUATION_LOG_FILE"].presence || Rails.application.config.x.situation_log_file
    end
  end

  def initialize(path = self.class.default_path)
    @path = File.expand_path(path)
  end

  def all
    read_document["entries"].sort_by { |entry| entry["logged_at"].to_s }.reverse
  end

  def find(id)
    all.find { |entry| entry["id"] == id }
  end

  def create(attrs)
    document = read_document
    now = Time.now.utc.iso8601
    entry = attrs.merge(
      "id" => attrs["id"] || SecureRandom.uuid,
      "logged_at" => attrs["logged_at"] || now,
      "updated_at" => now
    )
    document["entries"] << entry
    write_document(document)
    entry
  end

  def update(id, attrs)
    document = read_document
    index = document["entries"].index { |entry| entry["id"] == id }
    raise StorageError, "No se encontró el registro." if index.nil?

    entry = document["entries"][index].merge(attrs).merge(
      "id" => id,
      "updated_at" => Time.now.utc.iso8601
    )
    document["entries"][index] = entry
    write_document(document)
    entry
  end

  def destroy(id)
    document = read_document
    remaining = document["entries"].reject { |entry| entry["id"] == id }
    raise StorageError, "No se encontró el registro." if remaining.length == document["entries"].length

    document["entries"] = remaining
    write_document(document)
    nil
  end

  private

  def read_document
    return empty_document unless File.exist?(@path)

    JSON.parse(File.read(@path))
  rescue JSON::ParserError, SystemCallError => e
    raise StorageError, "No se pudo leer el archivo de registros: #{e.message}"
  end

  def write_document(document)
    dir = File.dirname(@path)
    FileUtils.mkdir_p(dir)
    tempfile = File.join(dir, ".#{File.basename(@path)}.tmp#{$$}")
    File.write(tempfile, JSON.pretty_generate(document) + "\n")
    FileUtils.mv(tempfile, @path)
  rescue SystemCallError, IOError => e
    raise StorageError, "No se pudo guardar el archivo de registros: #{e.message}"
  end

  def empty_document
    { "version" => FILE_FORMAT_VERSION, "entries" => [] }
  end
end
