# frozen_string_literal: true

namespace :ofn do
  desc "Send representative emails using the sample data created by `ofn:sample_data`"
  task test_emails: :environment do
    ensure_sample_data!

    EmailTestData.new.run
  end

  def ensure_sample_data!
    return if Spree::Order.count.positive? && Enterprise.count.positive?

    Rake::Task["ofn:sample_data"].invoke
  end
end

class EmailTestData
  CONFIG_PATH = Rails.root.join("tmp/email_test_config.yml")
  DEFAULT_CONFIG = {
    "recipient" => nil,
    "emails" => {}
  }.freeze

  EMAIL_KEYS = [
    "BackorderMailer#backorder_failed",
    "BackorderMailer#backorder_incomplete",
    "EnterpriseMailer#manager_invitation",
    "EnterpriseMailer#welcome",
    "PaymentMailer#authorization_required",
    "PaymentMailer#authorize_payment",
    "PaymentMailer#refund_available",
    "ProducerMailer#order_cycle_report",
    "ReportMailer#report_ready",
    "Spree::OrderMailer#cancel_email",
    "Spree::OrderMailer#cancel_email_for_shop",
    "Spree::OrderMailer#confirm_email_for_customer",
    "Spree::OrderMailer#confirm_email_for_shop",
    "Spree::OrderMailer#invoice_email",
    "Spree::ShipmentMailer#shipped_email",
    "Spree::TestMailer#test_email",
    "Spree::UserMailer#confirmation_instructions",
    "Spree::UserMailer#reset_password_instructions",
    "Spree::UserMailer#signup_confirmation",
    "SubscriptionMailer#confirmation_email",
    "SubscriptionMailer#confirmation_summary_email",
    "SubscriptionMailer#empty_email",
    "SubscriptionMailer#failed_payment_email",
    "SubscriptionMailer#placement_email",
    "SubscriptionMailer#placement_summary_email"
  ].freeze

  def run
    config = load_email_config
    config = configure_recipient(config)

    email_keys = display_available_emails

    print_selection_help
    input = $stdin.gets.to_s.strip

    if input.present?
      selected_indexes = parse_selection_input(input, email_keys.size)
      config["emails"] = build_email_config(email_keys, selected_indexes)
    else
      config["emails"] = config.fetch("emails", {}).presence ||
        build_email_config(email_keys, (1..email_keys.size).to_a)
    end

    save_email_config(config)
    send_selected_emails(config["emails"])
  end

  def load_email_config
    return DEFAULT_CONFIG.deep_dup unless File.exist?(CONFIG_PATH)

    DEFAULT_CONFIG.deep_merge(YAML.load_file(CONFIG_PATH) || {})
  end

  def save_email_config(config)
    File.write(CONFIG_PATH, config.to_yaml)
  end

  def configure_recipient(config)
    current_recipient = config["recipient"]

    $stdout.puts("\nMake sure to enter an email address you have access to!")
    $stdout.puts(
      if current_recipient.present?
        "Current recipient: #{current_recipient}"
      else
        "Currently no recipient configured."
      end
    )

    $stdout.print("Enter recipient email (empty keeps current): ")

    input = $stdin.gets.to_s.strip
    return config if input.empty?

    config.merge("recipient" => input)
  end

  def display_available_emails
    $stdout.puts("\nAvailable emails:\n")

    config = load_email_config
    email_keys = []

    EMAIL_KEYS.each_with_index do |key, index|
      marker = config.fetch("emails", {}).fetch(key, false) ? "x" : " "
      $stdout.puts(format("%2d. [%s] %s", index + 1, marker, key))
      email_keys << key
    end

    email_keys
  end

  def print_selection_help
    $stdout.puts
    $stdout.puts "Examples:"
    $stdout.puts "  1,4,7"
    $stdout.puts "  1-5"
    $stdout.puts "  all"
    $stdout.puts "  empty input keeps current selection"
    $stdout.puts
    $stdout.print "Select emails to send: "
  end

  def parse_selection_input(input, total)
    return (1..total).to_a if input.downcase == "all"

    input.split(",").flat_map do |part|
      parse_selection_part(part.strip)
    end
  end

  def parse_selection_part(part)
    return part.to_i unless part.include?("-")

    from, to = part.split("-").map(&:to_i)
    (from..to).to_a
  end

  def build_email_config(email_keys, selected_indexes)
    config = email_keys.index_with(false)

    selected_indexes.each do |index|
      key = email_keys[index - 1]
      config[key] = true if key
    end

    config
  end

  def send_selected_emails(email_config)
    EMAIL_KEYS.each do |key|
      next unless email_config[key]

      begin
        send_email_for(key)
        puts "✓ #{key}"
      rescue StandardError => e
        puts "❌ #{key}: #{e.class} - #{e.message}"
      end
    end
  end

  def send_email_for(key)
    case key
    when "BackorderMailer#backorder_failed"
      BackorderMailer.backorder_failed(sample_order).deliver_now
    when "BackorderMailer#backorder_incomplete"
      order = sample_order
      distributor = order.distributor
      user = distributor&.owner
      order_cycle = order.order_cycle
      return if distributor.blank? || user.blank? || order_cycle.blank?

      BackorderMailer.backorder_incomplete(
        user,
        distributor,
        order_cycle,
        "https://example.org/api/dfc/Enterprises/#{distributor.permalink}/Orders/#{order.id}"
      ).deliver_now
    when "EnterpriseMailer#manager_invitation"
      EnterpriseMailer.manager_invitation(sample_enterprise, sample_user).deliver_now
    when "EnterpriseMailer#welcome"
      EnterpriseMailer.welcome(sample_enterprise).deliver_now
    when "PaymentMailer#authorization_required"
      PaymentMailer.authorization_required(sample_payment).deliver_now
    when "PaymentMailer#authorize_payment"
      PaymentMailer.authorize_payment(sample_payment).deliver_now
    when "PaymentMailer#refund_available"
      PaymentMailer.refund_available(10.0, sample_payment, "http://example.com/status").deliver_now
    when "ProducerMailer#order_cycle_report"
      ProducerMailer.order_cycle_report(sample_producer, sample_order_cycle).deliver_now
    when "ReportMailer#report_ready"
      report_blob = ReportBlob.last || FakeBlob.new
      ReportMailer.with(blob: report_blob).report_ready.deliver_now
    when "Spree::OrderMailer#cancel_email"
      Spree::OrderMailer.cancel_email(sample_order).deliver_now
    when "Spree::OrderMailer#cancel_email_for_shop"
      Spree::OrderMailer.cancel_email_for_shop(sample_order).deliver_now
    when "Spree::OrderMailer#confirm_email_for_customer"
      Spree::OrderMailer.confirm_email_for_customer(sample_order).deliver_now
    when "Spree::OrderMailer#confirm_email_for_shop"
      Spree::OrderMailer.confirm_email_for_shop(sample_order).deliver_now
    when "Spree::OrderMailer#invoice_email"
      Spree::OrderMailer.invoice_email(sample_order).deliver_now
    when "Spree::ShipmentMailer#shipped_email"
      shipment = sample_shipment
      return if shipment.blank?

      Spree::ShipmentMailer.shipped_email(shipment, delivery: true).deliver_now
      Spree::ShipmentMailer.shipped_email(shipment, delivery: false).deliver_now
    when "Spree::TestMailer#test_email"
      Spree::TestMailer.test_email(sample_user).deliver_now
    when "Spree::UserMailer#confirmation_instructions"
      Spree::UserMailer.confirmation_instructions(sample_user, "test_token").deliver_now
    when "Spree::UserMailer#reset_password_instructions"
      Spree::UserMailer.reset_password_instructions(sample_user, "test_token").deliver_now
    when "Spree::UserMailer#signup_confirmation"
      Spree::UserMailer.signup_confirmation(sample_user).deliver_now
    when "SubscriptionMailer#confirmation_email"
      SubscriptionMailer.confirmation_email(sample_order).deliver_now
    when "SubscriptionMailer#confirmation_summary_email"
      SubscriptionMailer.confirmation_summary_email(subscription_summary).deliver_now
    when "SubscriptionMailer#empty_email"
      SubscriptionMailer.empty_email(sample_order, []).deliver_now
    when "SubscriptionMailer#failed_payment_email"
      SubscriptionMailer.failed_payment_email(sample_order).deliver_now
    when "SubscriptionMailer#placement_email"
      SubscriptionMailer.placement_email(sample_order, []).deliver_now
    when "SubscriptionMailer#placement_summary_email"
      SubscriptionMailer.placement_summary_email(subscription_summary).deliver_now
    else
      raise "No sender defined for #{key}"
    end
  end

  def subscription_summary
    summary = OrderManagement::Subscriptions::Summary.new(sample_distributor.id)
    summary.record_order(sample_order)
    summary.record_success(sample_order)
    summary
  end

  def sample_order
    @sample_order ||= Spree::Order.complete.includes(:line_items).find do |order|
      order.line_items.any?
    end || Spree::Order.order(:id).last
  end

  def sample_shipment
    @sample_shipment ||= Spree::Shipment.includes(:order).order(:id).last
  end

  def sample_user
    @sample_user ||= Spree::User.order(:id).last || Spree::User.first || sample_order.user
  end

  def sample_enterprise
    @sample_enterprise ||= sample_order.distributor || Enterprise.order(:id).last
  end

  def sample_distributor
    @sample_distributor ||= sample_enterprise || sample_order&.distributor
  end

  def sample_producer
    @sample_producer ||= sample_order&.line_items&.first&.variant&.enterprise || Enterprise.order(:id).last
  end

  def sample_order_cycle
    @sample_order_cycle ||= sample_order&.order_cycle || OrderCycle.order(:id).last
  end

  def sample_payment
    @sample_payment ||= sample_order&.payments&.first || Spree::Payment.order(:id).last
  end
end

class FakeBlob
  def filename
    "sample_report.csv"
  end

  def content_type
    "text/csv"
  end

  def download
    "sample_report.csv"
  end
end
