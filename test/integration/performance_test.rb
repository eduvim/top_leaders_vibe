require "test_helper"

# T030 — NFR-03: with 500 stored entries, list and save complete under 2 s.
class PerformanceTest < ActionDispatch::IntegrationTest
  NFR_LIMIT = 2.0

  def setup
    @tmpdir = Dir.mktmpdir
    ENV["SITUATION_LOG_FILE"] = File.join(@tmpdir, "entries.json")
    repository = EntryRepository.new
    500.times do |i|
      repository.create({
        "what_happened" => "Situación de prueba número #{i} con algo de texto para medir.",
        "meaning" => "Significado #{i}",
        "emotion_raw" => "Emoción #{i}",
        "emotion_tag" => "emoción #{i}",
        "intensity" => (i % 5) + 1,
        "reaction" => "Reacción #{i}",
        "logged_at" => (Time.utc(2026, 1, 1) + i * 60).iso8601,
        "status" => "saved"
      })
    end
  end

  def teardown
    FileUtils.remove_entry(@tmpdir) if @tmpdir
    ENV["SITUATION_LOG_FILE"] = nil
  end

  test "list of 500 entries renders under the NFR limit" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    get entries_path
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_response :success
    assert_operator elapsed, :<, NFR_LIMIT, "list took #{elapsed.round(3)}s with 500 entries"
  end

  test "save with 500 existing entries completes under the NFR limit" do
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    post entries_path, params: {
      entry: { what_happened: "Nueva situación", meaning: "", emotion_raw: "Miedo", intensity: "3", reaction: "" },
      commit: "save"
    }
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    assert_redirected_to entry_path(JSON.parse(File.read(ENV["SITUATION_LOG_FILE"]))["entries"].last["id"])
    assert_operator elapsed, :<, NFR_LIMIT, "save took #{elapsed.round(3)}s with 500 entries"
  end
end
