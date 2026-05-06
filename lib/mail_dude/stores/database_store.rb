# frozen_string_literal: true

module MailDude
  module Stores
    class DatabaseStore < Base
      def write(mail)
        ensure_table!
        record = build_record(mail)
        StoredEmail.create!(attributes_for(record))
        record
      rescue ActiveRecord::StatementInvalid, ActiveRecord::ActiveRecordError => e
        raise StorageError, "MailDude database storage failed: #{e.message}"
      end

      def list(page: 1, per_page: MailDude.configuration.default_per_page, query: nil)
        ensure_table!
        records = StoredEmail.order(captured_at: :desc).map { |row| record_from_row(row, raw: false) }
        page_for(records, page: page, per_page: per_page, query: query)
      end

      def find(id)
        ensure_table!
        valid_id = validate_id!(id)
        row = StoredEmail.find_by(uid: valid_id)
        raise MessageNotFoundError, 'Message not found' unless row

        record_from_row(row, raw: true)
      end

      def delete(id)
        ensure_table!
        valid_id = validate_id!(id)
        row = StoredEmail.find_by(uid: valid_id)
        return false unless row

        row.destroy!
        true
      end

      def clear
        ensure_table!
        StoredEmail.delete_all
      end

      def prune(max_messages: MailDude.configuration.max_messages,
                retention_period: MailDude.configuration.retention_period)
        ensure_table!
        ids = prune_ids(list(per_page: StoredEmail.count).records, max_messages: max_messages,
                                                                   retention_period: retention_period)
        StoredEmail.where(uid: ids).delete_all
      end

      private

      def attributes_for(record)
        metadata = record.metadata
        {
          uid: record.id,
          captured_at: Time.iso8601(metadata['captured_at']),
          subject: metadata['subject'],
          from_addresses_json: JSON.generate(metadata['from']),
          sender_addresses_json: JSON.generate(metadata['sender']),
          to_addresses_json: JSON.generate(metadata['to']),
          cc_addresses_json: JSON.generate(metadata['cc']),
          bcc_addresses_json: JSON.generate(metadata['bcc']),
          reply_to_addresses_json: JSON.generate(metadata['reply_to']),
          message_id: metadata['message_id'],
          content_type: metadata['content_type'],
          mailer: metadata['mailer'],
          mailer_action: metadata['mailer_action'],
          has_html: metadata['has_html'],
          has_text: metadata['has_text'],
          has_attachments: metadata['has_attachments'],
          attachments_count: metadata['attachments_count'],
          size_bytes: metadata['size_bytes'],
          metadata_json: JSON.generate(metadata),
          raw_message: record.raw_source
        }
      end

      def ensure_table!
        return if StoredEmail.connection.data_source_exists?(StoredEmail.table_name)

        raise StorageError,
              'MailDude database storage requires the mail_dude_stored_emails table. Run bin/rails db:migrate.'
      end

      def record_from_row(row, raw:)
        MessageRecord.new(id: row.uid, metadata: JSON.parse(row.metadata_json), raw_source: (row.raw_message if raw))
      end
    end
  end
end
