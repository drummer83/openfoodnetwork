# frozen_string_literal: true

require_relative "../spec_helper"

RSpec.describe AffiliateSalesQuery do
  subject(:query) { described_class }

  describe ".data" do
    let(:order) { create(:order_with_totals_and_distribution, :completed) }
    let(:today) { Time.zone.today }
    let(:yesterday) { Time.zone.yesterday }
    let(:tomorrow) { Time.zone.tomorrow }

    it "returns data" do
      # Test data creation takes time.
      # So I'm executing more tests in one `it` block here.
      # And make it simpler to call the subject many times:
      count_rows = lambda do |**args|
        query.data(order.distributor, **args).count
      end

      # Without any filters:
      expect(count_rows.call).to eq 1

      # From today:
      expect(count_rows.call(start_date: today)).to eq 1

      # Until today:
      expect(count_rows.call(end_date: today)).to eq 1

      # Just today:
      expect(count_rows.call(start_date: today, end_date: today)).to eq 1

      # Yesterday:
      expect(count_rows.call(start_date: yesterday, end_date: yesterday)).to eq 0

      # Until yesterday:
      expect(count_rows.call(end_date: yesterday)).to eq 0

      # From tomorrow:
      expect(count_rows.call(start_date: tomorrow)).to eq 0
    end
  end

  describe ".label_row" do
    it "converts an array to a hash" do
      row = [
        "Apples",
        "item", "item", nil, nil,
        15.50,
        "3210", "3211",
        3,
      ]
      expect(query.label_row(row)).to eq(
        {
          product_name: "Apples",
          unit_name: "item",
          unit_type: "item",
          units: nil,
          unit_presentation: nil,
          price: 15.50,
          distributor_postcode: "3210",
          supplier_postcode: "3211",
          quantity_sold: 3,
        }
      )
    end
  end
end
