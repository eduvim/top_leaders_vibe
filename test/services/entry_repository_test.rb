require "test_helper"

# T004 — EntryRepository tests (contracts/storage-file.md, data-model.md).
# Run BEFORE implementation: these must fail, then pass after T005.
class EntryRepositoryTest < ActiveSupport::TestCase
  def setup
    @tmpdir = Dir.mktmpdir
    @path = File.join(@tmpdir, "entries.json")
    @repo = EntryRepository.new(@path)
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir
  end

  def entry_attrs(overrides = {})
    {
      "what_happened" => "Discutí con mi hermano.",
      "meaning" => "Pensé que no me tomaba en cuenta.",
      "emotion_raw" => "Tristeza",
      "emotion_tag" => "tristeza",
      "intensity" => 4,
      "reaction" => "Dejé de responderle.",
      "status" => "saved"
    }.merge(overrides)
  end

  test "all returns empty list when file is missing" do
    assert_empty @repo.all
  end

  test "create persists an entry with id and timestamps and find returns it" do
    entry = @repo.create(entry_attrs)
    assert_match(/\A[0-9a-f-]{36}\z/, entry["id"])
    assert_not_nil entry["logged_at"]
    assert_not_nil entry["updated_at"]
    assert_equal entry, @repo.find(entry["id"])
  end

  test "create preserves an explicitly provided logged_at" do
    fixed = "2026-10-01T10:00:00Z"
    entry = @repo.create(entry_attrs("logged_at" => fixed))
    assert_equal fixed, entry["logged_at"]
  end

  test "file format is { version: 1, entries: [...] } and JSON-parsable" do
    @repo.create(entry_attrs)
    doc = JSON.parse(File.read(@path))
    assert_equal 1, doc["version"]
    assert_instance_of Array, doc["entries"]
    assert_equal 1, doc["entries"].length
  end

  test "all returns entries newest first" do
    older = @repo.create(entry_attrs("logged_at" => "2026-10-01T10:00:00Z", "emotion_raw" => "Miedo"))
    newer = @repo.create(entry_attrs("logged_at" => "2026-10-02T10:00:00Z", "emotion_raw" => "Alegría"))
    assert_equal [ newer["id"], older["id"] ], @repo.all.map { |e| e["id"] }
  end

  test "update replaces an entry in place and refreshes updated_at" do
    entry = @repo.create(entry_attrs("logged_at" => "2026-10-01T10:00:00Z"))
    sleep 0.01
    updated = @repo.update(entry["id"], entry_attrs("reaction" => "Respiré y esperé.", "logged_at" => "2026-10-01T10:00:00Z"))
    assert_equal "Respiré y esperé.", updated["reaction"]
    assert_equal entry["logged_at"], updated["logged_at"]
    assert updated["updated_at"] >= entry["updated_at"]
    assert_equal 1, @repo.all.length
    assert_equal updated, @repo.find(entry["id"])
  end

  test "destroy removes the entry from the file" do
    entry = @repo.create(entry_attrs)
    @repo.destroy(entry["id"])
    assert_nil @repo.find(entry["id"])
    assert_empty @repo.all
  end

  test "find returns nil for an unknown id" do
    assert_nil @repo.find("nope")
  end

  test "corrupt JSON raises StorageError and is not overwritten" do
    File.write(@path, "{ not valid json")
    error = assert_raises(EntryRepository::StorageError) { @repo.all }
    assert_match(/No se pudo leer/, error.message)
    assert_raises(EntryRepository::StorageError) { @repo.create(entry_attrs) }
    assert_equal "{ not valid json", File.read(@path)
  end

  test "unwritable path raises StorageError on create and writes nothing" do
    locked = File.join(@tmpdir, "locked")
    Dir.mkdir(locked)
    File.chmod(0o500, locked)
    bad_repo = EntryRepository.new(File.join(locked, "entries.json"))
    assert_raises(EntryRepository::StorageError) { bad_repo.create(entry_attrs) }
    assert File.exist?(@tmpdir)
  end

  test "create makes missing parent directories (contract: first write)" do
    nested = File.join(@tmpdir, "a", "b")
    repo = EntryRepository.new(File.join(nested, "entries.json"))
    repo.create(entry_attrs)
    assert File.exist?(File.join(nested, "entries.json"))
  end

  test "writes are atomic: no temp file remains after a successful write" do
    @repo.create(entry_attrs)
    @repo.create(entry_attrs)
    assert_equal %w[entries.json], Dir.children(@tmpdir)
  end

  test "default path honors SITUATION_LOG_FILE at runtime" do
    env_path = File.join(@tmpdir, "from_env.json")
    ENV["SITUATION_LOG_FILE"] = env_path
    repo = EntryRepository.new
    repo.create(entry_attrs)
    assert File.exist?(env_path)
  ensure
    ENV["SITUATION_LOG_FILE"] = nil
  end
end
