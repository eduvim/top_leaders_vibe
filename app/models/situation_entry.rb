# Emotional situation entry captured through the guided 5-question form
# (spec §8, data-model.md). Plain ActiveModel class — no database; all
# persistence goes through EntryRepository.
class SituationEntry
  include ActiveModel::Model
  include ActiveModel::Validations::Callbacks

  STATUSES = %w[saved draft].freeze

  MAX_LENGTHS = {
    what_happened: 2000,
    meaning: 1000,
    reaction: 2000,
    emotion_raw: 60
  }.freeze

  attr_accessor :id, :what_happened, :meaning, :emotion_raw, :emotion_tag,
                :intensity, :reaction, :logged_at, :updated_at, :status

  validates :status, inclusion: { in: STATUSES }
  MAX_LENGTHS.each do |field, limit|
    validates field, length: { maximum: limit }, allow_nil: true
  end
  validate :validate_intensity
  validate :validate_emotion_when_saved

  before_validation :normalize

  class << self
    def from_h(hash)
      new(
        id: hash["id"],
        what_happened: hash["what_happened"],
        meaning: hash["meaning"],
        emotion_raw: hash["emotion_raw"],
        emotion_tag: hash["emotion_tag"],
        intensity: hash["intensity"],
        reaction: hash["reaction"],
        logged_at: parse_time(hash["logged_at"]),
        updated_at: parse_time(hash["updated_at"]),
        status: hash["status"]
      )
    end

    private

    def parse_time(value)
      value.is_a?(String) ? Time.iso8601(value) : value
    end
  end

  def to_h
    {
      "id" => id, "what_happened" => what_happened, "meaning" => meaning,
      "emotion_raw" => emotion_raw, "emotion_tag" => emotion_tag,
      "intensity" => intensity, "reaction" => reaction,
      "logged_at" => serialize_time(logged_at), "updated_at" => serialize_time(updated_at),
      "status" => status
    }
  end

  def draft?
    status == "draft"
  end

  def saved?
    status == "saved"
  end

  private

  def serialize_time(value)
    value.is_a?(Time) ? value.utc.iso8601 : value
  end

  def normalize
    %i[what_happened meaning reaction emotion_raw].each do |field|
      value = public_send(field)
      next if value.nil?

      value = value.strip
      public_send(:"#{field}=", value.presence)
    end
    self.emotion_tag = emotion_raw&.downcase&.gsub(/\s+/, " ")
    self.intensity = cast_intensity
  end

  def cast_intensity
    return nil if intensity.blank?

    raw = intensity.is_a?(String) ? intensity.strip : intensity
    raw.to_s.match?(/\A-?\d+\z/) ? raw.to_i : raw
  end

  def validate_intensity
    return if intensity.nil? || (intensity.is_a?(Integer) && intensity.between?(1, 5))

    errors.add(:intensity, "debe ser un número entero entre 1 y 5")
  end

  def validate_emotion_when_saved
    errors.add(:emotion_raw, "debes indicar la emoción para guardar el registro") if saved? && emotion_raw.blank?
  end
end
