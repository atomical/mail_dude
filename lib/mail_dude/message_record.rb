# frozen_string_literal: true

module MailDude
  class MessageRecord
    attr_reader :id, :metadata, :raw_source

    def initialize(id:, metadata:, raw_source: nil)
      @id = id
      @metadata = metadata.stringify_keys
      @raw_source = raw_source
    end

    def full?
      raw_source.present?
    end
  end
end
