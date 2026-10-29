# frozen_string_literal: true

namespace :ofn do
  desc "Send representative emails using the sample data created by `ofn:sample_data`"
  task test_emails: :environment do
    ensure_sample_data!

    EmailTestData.new.send_all
  end

  def ensure_sample_data!
    return if Spree::Order.count.positive? && Enterprise.count.positive?

    Rake::Task["ofn:sample_data"].invoke
  end
end

class EmailTestData
  def send_all
    send_order_emails
    send_subscription_emails
    send_shipments
    send_backorders
    send_report_email
  end

  private

  def send_order_emails
    # These are the real order records created by the sample-data task, so they
    # carry realistic numbers, addresses and item data instead of handcrafted fakes.
    order = sample_order

    Spree::OrderMailer.cancel_email(order).deliver_now
    Spree::OrderMailer.cancel_email_for_shop(order).deliver_now
    Spree::OrderMailer.confirm_email_for_customer(order).deliver_now
    Spree::OrderMailer.confirm_email_for_shop(order).deliver_now
    Spree::OrderMailer.invoice_email(order).deliver_now
  end

  def send_subscription_emails
    order = sample_order

    SubscriptionMailer.confirmation_email(order).deliver_now
    SubscriptionMailer.empty_email(order, []).deliver_now
    SubscriptionMailer.placement_email(order, []).deliver_now
    SubscriptionMailer.failed_payment_email(order).deliver_now
  end

  def send_shipments
    shipment = sample_shipment
    return if shipment.blank?

    Spree::ShipmentMailer.shipped_email(shipment, delivery: true).deliver_now
    Spree::ShipmentMailer.shipped_email(shipment, delivery: false).deliver_now
  end

  def send_backorders
    order = sample_order
    return if order.blank?

    BackorderMailer.backorder_failed(order).deliver_now

    distributor = order.distributor
    return if distributor.blank?

    order_cycle = order.order_cycle
    user = distributor.owner
    return if user.blank?

    BackorderMailer.backorder_incomplete(
      user,
      distributor,
      order_cycle,
      "https://example.org/api/dfc/Enterprises/#{distributor.permalink}/Orders/#{order.id}"
    ).deliver_now
  end

  def send_report_email
    report_blob = ReportBlob.last
    return if report_blob.blank?

    ReportMailer.with(blob: report_blob).report_ready.deliver_now
  end

  def sample_order
    @sample_order ||= Spree::Order.complete.order(:id).last || Spree::Order.order(:id).last
  end

  def sample_shipment
    @sample_shipment ||= Spree::Shipment.includes(:order).order(:id).last
  end
end
