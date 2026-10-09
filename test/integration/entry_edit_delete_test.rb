require "test_helper"

# T023 — US-01 AC6 / RF-08 edit and delete tests.
class EntryEditDeleteTest < ActionDispatch::IntegrationTest
  def setup
    @tmpdir = Dir.mktmpdir
    ENV["SITUATION_LOG_FILE"] = File.join(@tmpdir, "entries.json")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir
    ENV["SITUATION_LOG_FILE"] = nil
  end

  def create_entry(attrs = {})
    EntryRepository.new.create({
      "what_happened" => "Discutí con mi hermano.",
      "meaning" => "Pensé que no me tomaba en cuenta.",
      "emotion_raw" => "Tristeza",
      "emotion_tag" => "tristeza",
      "intensity" => 4,
      "reaction" => "Dejé de responderle.",
      "status" => "saved"
    }.merge(attrs))
  end

  def stored_entries
    return [] unless File.exist?(ENV["SITUATION_LOG_FILE"])

    JSON.parse(File.read(ENV["SITUATION_LOG_FILE"]))["entries"]
  end

  test "GET edit prefills all fields" do
    entry = create_entry
    get edit_entry_path(entry["id"])
    assert_response :success
    assert_match(/Discutí con mi hermano\./, response.body)
    assert_match(/Pensé que no me tomaba en cuenta\./, response.body)
    assert_match(/Tristeza/, response.body)
    assert_match(/Dejé de responderle\./, response.body)
    assert_match(/checked(="checked")?/, response.body)
  end

  test "PATCH updates the field, refreshes updated_at, and persists to the file" do
    entry = create_entry
    sleep 1.05 # timestamps have second resolution
    patch entry_path(entry["id"]), params: {
      entry: {
        what_happened: "Discutí con mi hermano.",
        meaning: "Pensé que no me tomaba en cuenta.",
        emotion_raw: "Tristeza",
        intensity: "4",
        reaction: "Respiré y esperé antes de responder."
      },
      commit: "save"
    }
    assert_redirected_to entry_path(entry["id"])
    updated = stored_entries.first
    assert_equal "Respiré y esperé antes de responder.", updated["reaction"]
    assert_equal entry["logged_at"], updated["logged_at"]
    assert updated["updated_at"] > entry["updated_at"]
  end

  test "PATCH with commit draft downgrades a saved entry to draft" do
    entry = create_entry
    patch entry_path(entry["id"]), params: {
      entry: { what_happened: "", meaning: "", emotion_raw: "", intensity: "", reaction: "" },
      commit: "draft"
    }
    assert_redirected_to entry_path(entry["id"])
    assert_equal "draft", stored_entries.first["status"]
  end

  test "PATCH with invalid intensity renders 422 and keeps the original intact" do
    entry = create_entry
    patch entry_path(entry["id"]), params: {
      entry: {
        what_happened: "x", meaning: "", emotion_raw: "Miedo", intensity: "6", reaction: ""
      },
      commit: "save"
    }
    assert_response :unprocessable_entity
    assert_equal "Tristeza", stored_entries.first["emotion_raw"]
    assert_equal 4, stored_entries.first["intensity"]
  end

  test "storage failure on PATCH keeps the original entry and shows the error" do
    entry = create_entry
    File.chmod(0o500, @tmpdir)

    patch entry_path(entry["id"]), params: {
      entry: { what_happened: "nuevo", meaning: "", emotion_raw: "Miedo", intensity: "3", reaction: "" },
      commit: "save"
    }
    assert_response :service_unavailable
    assert_match(/No se pudo guardar tu registro\./, response.body)
    File.chmod(0o700, @tmpdir)
    assert_equal "Tristeza", stored_entries.first["emotion_raw"]
  end

  test "DELETE removes the entry from the file and the list" do
    entry = create_entry
    delete entry_path(entry["id"])
    assert_redirected_to entries_path
    assert_empty stored_entries
    follow_redirect!
    refute_match(/Discutí con mi hermano\./, response.body)
    assert_match(/El registro se eliminó\./, response.body)
  end

  test "storage failure on DELETE keeps the entry and shows the error" do
    entry = create_entry
    File.chmod(0o500, @tmpdir)

    delete entry_path(entry["id"])
    assert_redirected_to entry_path(entry["id"])
    File.chmod(0o700, @tmpdir)
    assert_equal 1, stored_entries.length
  end

  test "edit, update, and destroy for an unknown id return 404" do
    get edit_entry_path("nope")
    assert_response :not_found
    patch entry_path("nope"), params: { entry: { what_happened: "x" }, commit: "save" }
    assert_response :not_found
    delete entry_path("nope")
    assert_response :not_found
  end
end
