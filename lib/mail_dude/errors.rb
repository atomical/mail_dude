# frozen_string_literal: true

module MailDude
  class Error < StandardError; end
  class DisabledEnvironmentError < Error; end
  class InvalidConfigurationError < Error; end
  class StorageError < Error; end
  class MessageNotFoundError < Error; end
  class AttachmentNotFoundError < Error; end
  class MessageTooLargeError < Error; end
end
