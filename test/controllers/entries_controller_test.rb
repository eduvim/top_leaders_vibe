require "test_helper"

# T012 — US-01 logging request tests, one per spec requirement RF-01..RF-06.
class EntriesControllerTest < ActionDispatch::IntegrationTest
  def setup
    @tmpdir = Dir.mktmpdir
    ENV["SITUATION_LOG_FILE"] = File.join(@tmpdir, "entries.json")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir
    ENV["SITUATION_LOG_FILE"] = nil
  end

  def valid_entry_params
    {
      what_happened: "Discutí con mi hermano.",
      meaning: "Pensé que no me tomaba en cuenta.",
      emotion_raw: "Tristeza",
      intensity: "4",
      reaction: "Dejé de responderle."
    }
  end

  def stored_entries
    return [] unless File.exist?(ENV["SITUATION_LOG_FILE"])

    JSON.parse(File.read(ENV["SITUATION_LOG_FILE"]))["entries"]
  end

  # RF-01
  test "GET new shows the 5 questions in the defined order" do
    get new_entry_path
    assert_response :success
    body = response.body
    positions = [
      body.index("¿Qué pasó?"),
      body.index("¿Qué significado le diste a lo que pasó?"),
      body.index("¿Qué emoción sentiste?"),
      body.index("¿Cómo fue de intensa?"),
      body.index("¿Cómo reaccionaste?")
    ]
    assert positions.all?(&:present?), "all 5 questions must appear"
    assert_equal positions, positions.sort, "questions must appear in order"
  end

  # RF-02
  test "POST with intensity 6 renders 422 with inline error and preserves data" do
    post entries_path, params: { entry: valid_entry_params.merge(intensity: "6"), commit: "save" }
    assert_response :unprocessable_entity
    assert_match(/entre 1 y 5/, response.body)
    assert_match(/Discutí con mi hermano\./, response.body)
    assert_empty stored_entries
  end

  test "POST with over-length text renders 422 and saves nothing" do
    post entries_path, params: { entry: valid_entry_params.merge(what_happened: "x" * 2001), commit: "save" }
    assert_response :unprocessable_entity
    assert_match(/demasiado largo/, response.body)
    assert_empty stored_entries
  end

  # RF-03
  test "POST with valid data persists a saved entry with UUID, timestamp, and normalized tag" do
    assert_nothing_raised do
      post entries_path, params: { entry: valid_entry_params, commit: "save" }
    end
    assert_redirected_to entry_path(stored_entries.first["id"])
    entry = stored_entries.first
    assert_match(/\A[0-9a-f-]{36}\z/, entry["id"])
    assert_not_nil entry["logged_at"]
    assert_equal "saved", entry["status"]
    assert_equal "tristeza", entry["emotion_tag"]
    assert_equal 4, entry["intensity"]
  end

  # RF-04
  test "successful save shows the confirmation notice and offers logging another situation" do
    post entries_path, params: { entry: valid_entry_params, commit: "save" }
    follow_redirect!
    assert_response :success
    assert_match(/Tu registro se guardó\./, response.body)
    assert_match(/Registrar otra situación/, response.body)
    assert_match(/Volver/, response.body)
  end

  # RF-05
  test "storage failure renders 503, keeps data on screen, shows no success notice" do
    locked = File.join(@tmpdir, "locked")
    Dir.mkdir(locked)
    File.chmod(0o500, locked)
    ENV["SITUATION_LOG_FILE"] = File.join(locked, "entries.json")

    post entries_path, params: { entry: valid_entry_params, commit: "save" }
    assert_response :service_unavailable
    assert_match(/No se pudo guardar tu registro\./, response.body)
    assert_match(/Discutí con mi hermano\./, response.body)
    assert_nil flash[:notice]
  end

  # RF-06 / D4
  test "POST with commit draft saves an empty entry as draft with its notice" do
    post entries_path, params: { entry: { what_happened: "", meaning: "", emotion_raw: "", intensity: "", reaction: "" }, commit: "draft" }
    assert_redirected_to entry_path(stored_entries.first["id"])
    entry = stored_entries.first
    assert_equal "draft", entry["status"]
    follow_redirect!
    assert_match(/Tu borrador se guardó\./, response.body)
  end

  test "GET show for an unknown id returns 404" do
    get entry_path("does-not-exist")
    assert_response :not_found
  end
end
