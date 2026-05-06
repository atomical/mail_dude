# frozen_string_literal: true

module MailDude
  module Stores
    class MemoryStore < Base
      def initialize
        @records = {}
        @mutex = Mutex.new
      end

      def write(mail)
        record = build_record(mail)
        mutex.synchronize { records[record.id] = record }
        record
      end

      def list(page: 1, per_page: MailDude.configuration.default_per_page, query: nil)
        mutex.synchronize { page_for(records.values, page: page, per_page: per_page, query: query) }
      end

      def find(id)
        valid_id = validate_id!(id)
        mutex.synchronize { records.fetch(valid_id) { raise MessageNotFoundError, 'Message not found' } }
      end

      def delete(id)
        valid_id = validate_id!(id)
        mutex.synchronize { !records.delete(valid_id).nil? }
      end

      def clear
        mutex.synchronize do
          count = records.length
          records.clear
          count
        end
      end

      def prune(max_messages: MailDude.configuration.max_messages,
                retention_period: MailDude.configuration.retention_period)
        mutex.synchronize do
          ids = prune_ids(records.values, max_messages: max_messages, retention_period: retention_period)
          ids.each { |id| records.delete(id) }
          ids.length
        end
      end

      private

      attr_reader :mutex, :records
    end
  end
end
