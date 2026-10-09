# Storage path for the emotional situation log (spec decision D6:
# a single JSON file on the user's desktop, overridable for tests and
# alternate locations).
TopLeaders::Application.configure do
  config.x.situation_log_file = ENV.fetch("SITUATION_LOG_FILE") do
    File.join(Dir.home, "Desktop", "emotional_situations.json")
  end
end
