require "test_helper"

# T013 — US-01 guided form happy path (system-level, no-JS driver).
# The beforeunload guard (RF-06) needs JavaScript and is verified manually
# per quickstart.md S4; this suite covers screen navigation and save flow.
class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :rack_test
end

class LogEntryTest < ApplicationSystemTestCase
  def setup
    @tmpdir = Dir.mktmpdir
    ENV["SITUATION_LOG_FILE"] = File.join(@tmpdir, "entries.json")
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir
    ENV["SITUATION_LOG_FILE"] = nil
  end

  test "guided form flow from the main screen to confirmation" do
    visit root_path
    click_on "Registrar situación"

    assert_selector "h1", text: "Registro de situación"
    %w[¿Qué\ pasó? ¿Qué\ significado\ le\ diste\ a\ lo\ que\ pasó? ¿Qué\ emoción\ sentiste? ¿Cómo\ fue\ de\ intensa? ¿Cómo\ reaccionaste?].each do |question|
      assert_text question
    end

    fill_in "¿Qué pasó?", with: "Discutí con mi hermano."
    fill_in "¿Qué emoción sentiste?", with: "Tristeza"
    choose "4 — Intensa"
    click_on "Guardar"

    assert_text "Tu registro se guardó."
    assert_text "Discutí con mi hermano."
    assert_text "Tristeza"
  end
end
