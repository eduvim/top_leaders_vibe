require "test_helper"

# T018 — US-02/03 viewing tests, one per module §11 requirement CRF-01..CRF-05.
class EntriesViewTest < ActionDispatch::IntegrationTest
  def setup
    @tmpdir = Dir.mktmpdir
    ENV["SITUATION_LOG_FILE"] = File.join(@tmpdir, "entries.json")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir
    ENV["SITUATION_LOG_FILE"] = nil
  end

  def create_entry(attrs)
    EntryRepository.new.create(attrs)
  end

  def entry_attrs(overrides = {})
    {
      "what_happened" => "Discutí con mi hermano por un mensaje que malinterpreté y la conversación escaló rápidamente.",
      "meaning" => "Pensé que no me tomaba en cuenta.",
      "emotion_raw" => "Tristeza",
      "emotion_tag" => "tristeza",
      "intensity" => 4,
      "reaction" => "Dejé de responderle el resto del día.",
      "status" => "saved"
    }.merge(overrides)
  end

  # CRF-01
  test "list is reachable from the main screen" do
    create_entry(entry_attrs)
    get root_path
    assert_response :success
    assert_match(/Mis registros/, response.body)

    get entries_path
    assert_response :success
    assert_match(/Discutí con mi hermano/, response.body)
  end

  # CRF-02
  test "list shows entries newest first with date, emotion, intensity, and snippet" do
    older = create_entry(entry_attrs("logged_at" => "2026-10-01T10:00:00Z", "emotion_tag" => "miedo", "emotion_raw" => "Miedo", "intensity" => 2))
    newer = create_entry(entry_attrs("logged_at" => "2026-10-02T10:00:00Z"))

    get entries_path
    assert_response :success
    assert response.body.index("tristeza") < response.body.index("miedo"),
           "newest entry (tristeza) must appear before the older one (miedo)"
    assert_match(/tristeza/, response.body)
    assert_match(%r{4/5}, response.body)
    assert_match(%r{2/5}, response.body)
    snippet = "Discutí con mi hermano por un mensaje que malinterpreté"
    assert_match(Regexp.new(Regexp.escape(snippet)), response.body)
    assert_match(/\.\.\./, response.body, "long text must be truncated")
  end

  test "draft entries show the Borrador badge in the list" do
    create_entry(entry_attrs("status" => "draft"))
    get entries_path
    assert_match(/Borrador/, response.body)
  end

  # CRF-03
  test "detail shows all 5 answers, blanks as —, and never the UUID" do
    entry = create_entry(entry_attrs("meaning" => nil, "intensity" => nil))
    get entry_path(entry["id"])
    assert_response :success
    assert_match(/Discutí con mi hermano/, response.body)
    assert_match(/Tristeza/, response.body)
    assert_match(/Dejé de responderle/, response.body)
    assert_match(/—/, response.body)
    visible_text = response.body.gsub(/<[^>]*>/, " ")
    refute_match(Regexp.new(Regexp.escape(entry["id"])), visible_text,
                 "the UUID must not be shown as content (URLs may contain it)")
  end

  # CRF-04
  test "empty state shows a message and an action to log a situation" do
    get entries_path
    assert_response :success
    assert_match(/Aún no tienes registros\./, response.body)
    assert_match(/Registrar situación/, response.body)
  end

  # CRF-05 (structural: single-profile app, no cross-profile access exists)
  test "list only ever renders entries from the configured storage file" do
    create_entry(entry_attrs)
    get entries_path
    assert_response :success
    doc = JSON.parse(File.read(ENV["SITUATION_LOG_FILE"]))
    assert_equal 1, doc["entries"].length
    assert_match(/tristeza/, response.body)
  end
end
