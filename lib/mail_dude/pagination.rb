# frozen_string_literal: true

module MailDude
  class Page
    attr_reader :page, :per_page, :records, :total_count

    def initialize(records:, page:, per_page:, total_count:)
      @records = records
      @page = normalize_positive(page, 1)
      @per_page = normalize_positive(per_page, MailDude.configuration.default_per_page)
      @total_count = total_count.to_i
    end

    def total_pages
      [(total_count.to_f / per_page).ceil, 1].max
    end

    def next_page
      page < total_pages ? page + 1 : nil
    end

    def previous_page
      page > 1 ? page - 1 : nil
    end

    private

    def normalize_positive(value, fallback)
      integer = Integer(value)
      integer.positive? ? integer : fallback
    rescue ArgumentError, TypeError
      fallback
    end
  end
end
