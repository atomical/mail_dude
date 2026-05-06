# frozen_string_literal: true

require 'fileutils'

module MailDude
  module Stores
    class FileStore < Base
      attr_reader :root

      def initialize(root = MailDude.configuration.storage_path)
        @root = Pathname.new(root.to_s)
        ensure_directories!
      end

      def write(mail)
        synchronize do
          record = build_record(mail)
          write_record(record)
          record
        end
      end

      def list(page: 1, per_page: MailDude.configuration.default_per_page, query: nil)
        page_for(load_metadata_records, page: page, per_page: per_page, query: query)
      end

      def find(id)
        valid_id = validate_id!(id)
        directory = message_path(valid_id)
        raise MessageNotFoundError, 'Message not found' unless directory.directory?

        metadata_file = directory.join('metadata.json')
        raw_file = directory.join('message.eml')
        raise MessageNotFoundError, 'Message not found' unless metadata_file.file? && raw_file.file?

        metadata = JSON.parse(metadata_file.read)
        MessageRecord.new(id: valid_id, metadata: metadata, raw_source: raw_file.binread)
      rescue JSON::ParserError
        raise MessageNotFoundError, 'Message not found'
      end

      def delete(id)
        valid_id = validate_id!(id)
        synchronize do
          directory = message_path(valid_id)
          return false unless directory.directory?

          FileUtils.rm_rf(directory)
          true
        end
      end

      def clear
        synchronize do
          directories = message_directories
          directories.each { |directory| FileUtils.rm_rf(directory) }
          directories.length
        end
      end

      def prune(max_messages: MailDude.configuration.max_messages,
                retention_period: MailDude.configuration.retention_period)
        synchronize do
          ids = prune_ids(load_metadata_records, max_messages: max_messages, retention_period: retention_period)
          ids.each { |id| FileUtils.rm_rf(message_path(id)) }
          ids.length
        end
      end

      private

      def ensure_directories!
        FileUtils.mkdir_p(messages_path)
      end

      def load_metadata_records
        message_directories.filter_map do |directory|
          metadata = JSON.parse(directory.join('metadata.json').read)
          MessageRecord.new(id: metadata.fetch('id'), metadata: metadata)
        rescue Errno::ENOENT, JSON::ParserError, KeyError
          Rails.logger.warn("MailDude skipped corrupt metadata in #{directory.basename}")
          nil
        end
      end

      def lock_path
        root.join('.lock')
      end

      def message_directories
        return [] unless messages_path.directory?

        messages_path.children.select(&:directory?).select { |path| path.basename.to_s.match?(ID_PATTERN) }
      end

      def message_path(id)
        messages_path.join(id)
      end

      def messages_path
        root.join('messages')
      end

      def synchronize
        ensure_directories!
        File.open(lock_path, File::RDWR | File::CREAT, 0o600) do |file|
          file.flock(File::LOCK_EX)
          yield
        ensure
          file.flock(File::LOCK_UN)
        end
      end

      def write_record(record)
        temporary = messages_path.join("#{record.id}.tmp-#{$PROCESS_ID}-#{SecureRandom.hex(4)}")
        final = message_path(record.id)
        FileUtils.mkdir_p(temporary)
        temporary.join('metadata.json').write(JSON.pretty_generate(record.metadata))
        temporary.join('message.eml').binwrite(record.raw_source)
        File.rename(temporary, final)
      ensure
        FileUtils.rm_rf(temporary)
      end
    end
  end
end
