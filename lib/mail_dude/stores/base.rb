# frozen_string_literal: true

require 'securerandom'

module MailDude
  module Stores
    class Base
      ID_PATTERN = /\A\d{8}T\d{12}Z-[a-f0-9]{16}\z/

      def write(_mail)
        raise NotImplementedError
      end

      def list(page: 1, per_page: MailDude.configuration.default_per_page, query: nil)
        raise NotImplementedError
      end

      def find(_id)
        raise NotImplementedError
      end

      def delete(_id)
        raise NotImplementedError
      end

      def clear
        raise NotImplementedError
      end

      def prune(max_messages: MailDude.configuration.max_messages,
                retention_period: MailDude.configuration.retention_period)
        raise NotImplementedError
      end

      private

      def build_record(mail, id: generate_id, captured_at: Time.now.utc)
        raw_source = raw_source_for(mail)
        metadata = MessageSerializer.new(mail, id: id, captured_at: captured_at, raw_source: raw_source).metadata
        MessageRecord.new(id: id, metadata: metadata, raw_source: raw_source)
      end

      def raw_source_for(mail)
        return mail.to_s if MailDude.configuration.capture_attachments

        AttachmentScrubber.new(mail).raw_source
      end

      def generate_id
        time = Time.now.utc
        "#{time.strftime('%Y%m%dT%H%M%S')}#{format('%06d', time.usec)}Z-#{SecureRandom.hex(8)}"
      end

      def validate_id!(id)
        return id.to_s if id.to_s.match?(ID_PATTERN)

        raise MessageNotFoundError, 'Message not found'
      end

      def page_for(records, page:, per_page:, query:)
        filtered = search(records, query)
        sorted = sort_records(filtered)
        normalized_page = normalize_positive(page, 1)
        normalized_per_page = normalize_positive(per_page, MailDude.configuration.default_per_page)
        offset = (normalized_page - 1) * normalized_per_page
        Page.new(records: sorted.slice(offset, normalized_per_page) || [],
                 page: normalized_page,
                 per_page: normalized_per_page,
                 total_count: sorted.length)
      end

      def prune_ids(records, max_messages:, retention_period:)
        sorted = sort_records(records)
        expired_ids = retention_period ? sorted.select { |record| expired?(record, retention_period) }.map(&:id) : []
        extra_ids = max_messages ? sorted.drop(max_messages.to_i).map(&:id) : []
        (expired_ids + extra_ids).uniq
      end

      def sort_records(records)
        records.sort_by { |record| record.metadata['captured_at'].to_s }.reverse
      end

      def search(records, query)
        return records if query.to_s.strip.blank?

        needle = query.to_s.downcase
        records.select { |record| searchable_text(record).downcase.include?(needle) }
      end

      def searchable_text(record)
        metadata = record.metadata
        values = %w[subject message_id mailer mailer_action].map { |key| metadata[key] }
        values += %w[from to cc bcc].flat_map { |key| Array(metadata[key]) }
        values.compact.join(' ')
      end

      def expired?(record, retention_period)
        captured_at = Time.iso8601(record.metadata['captured_at'].to_s)
        captured_at < Time.now.utc - retention_period
      rescue ArgumentError, TypeError
        false
      end

      def normalize_positive(value, fallback)
        integer = Integer(value)
        integer.positive? ? integer : fallback
      rescue ArgumentError, TypeError
        fallback
      end
    end
  end
end
