require "test_helper"

# T006 — SituationEntry model tests (data-model.md rules, D1-D4).
# Run BEFORE implementation: these must fail, then pass after T007.
class SituationEntryTest < ActiveSupport::TestCase
  def valid_attrs
    {
      what_happened: "Discutí con mi hermano.",
      meaning: "Pensé que no me tomaba en cuenta.",
      emotion_raw: "Tristeza",
      intensity: 4,
      reaction: "Dejé de responderle."
    }
  end

  test "is valid with all fields as saved (D1-D3)" do
    entry = SituationEntry.new(valid_attrs.merge(status: "saved"))
    assert entry.valid?, entry.errors.full_messages.join(", ")
  end

  test "all questions optional: valid as draft with every field empty (D3/D4)" do
    entry = SituationEntry.new(status: "draft")
    assert entry.valid?, entry.errors.full_messages.join(", ")
  end

  test "saving as completed requires the emotion (research §11)" do
    entry = SituationEntry.new(valid_attrs.except(:emotion_raw).merge(status: "saved"))
    assert entry.invalid?
    assert entry.errors[:emotion_raw].present?
  end

  test "intensity accepts integers 1 to 5 (D1)" do
    (1..5).each do |i|
      entry = SituationEntry.new(valid_attrs.merge(intensity: i, status: "draft"))
      assert entry.valid?, "intensity #{i} should be valid"
    end
  end

  test "intensity rejects 0, 6, non-integers, and out-of-range text (RF-02)" do
    [ 0, 6, 5.5, "alto", -1 ].each do |bad|
      entry = SituationEntry.new(valid_attrs.merge(intensity: bad, status: "draft"))
      assert entry.invalid?, "intensity #{bad.inspect} should be invalid"
      assert entry.errors[:intensity].present?
    end
  end

  test "intensity may be blank (D3)" do
    entry = SituationEntry.new(valid_attrs.merge(intensity: nil, status: "saved"))
    assert entry.valid?
  end

  test "rejects over-length text (A1: 2000/1000/2000/60)" do
    entry = SituationEntry.new(valid_attrs.merge(
      what_happened: "x" * 2001, status: "draft"
    ))
    assert entry.invalid?
    assert entry.errors[:what_happened].present?

    entry = SituationEntry.new(valid_attrs.merge(
      meaning: "x" * 1001, status: "draft"
    ))
    assert entry.invalid?
    assert entry.errors[:meaning].present?

    entry = SituationEntry.new(valid_attrs.merge(
      reaction: "x" * 2001, status: "draft"
    ))
    assert entry.invalid?
    assert entry.errors[:reaction].present?

    entry = SituationEntry.new(valid_attrs.merge(
      emotion_raw: "x" * 61, status: "draft"
    ))
    assert entry.invalid?
    assert entry.errors[:emotion_raw].present?
  end

  test "derives emotion_tag: lowercase, stripped, collapsed whitespace (D2)" do
    entry = SituationEntry.new(valid_attrs.merge(emotion_raw: "  Tristeza   tras  pelea  "))
    entry.valid?
    assert_equal "tristeza tras pelea", entry.emotion_tag
  end

  test "emotion_tag is empty when emotion_raw is empty" do
    entry = SituationEntry.new(status: "draft")
    entry.valid?
    assert_nil entry.emotion_tag
  end

  test "status must be saved or draft (D4)" do
    entry = SituationEntry.new(valid_attrs.merge(status: "published"))
    assert entry.invalid?
    assert entry.errors[:status].present?
  end

  test "from_h round-trips persisted attributes into the model" do
    persisted = {
      "id" => "abc-123", "what_happened" => "Situación", "meaning" => "Significado",
      "emotion_raw" => "Miedo", "emotion_tag" => "miedo", "intensity" => 3,
      "reaction" => "Congelarme", "logged_at" => "2026-10-01T10:00:00Z",
      "updated_at" => "2026-10-01T10:00:00Z", "status" => "saved"
    }
    entry = SituationEntry.from_h(persisted)
    assert_equal "abc-123", entry.id
    assert_equal "Miedo", entry.emotion_raw
    assert_equal "miedo", entry.emotion_tag
    assert_equal 3, entry.intensity
    assert_equal "saved", entry.status
  end
end
