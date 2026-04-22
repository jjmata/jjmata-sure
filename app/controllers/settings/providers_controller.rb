class Settings::ProvidersController < ApplicationController
  layout "settings"

  before_action :ensure_admin, only: [ :show ]

  def show
    @breadcrumbs = [
      [ "Home", root_path ],
      [ "Connections", nil ]
    ]

    prepare_show_context
  rescue ActiveRecord::Encryption::Errors::Configuration => e
    Rails.logger.error("Active Record Encryption not configured: #{e.message}")
    @encryption_error = true
  end

  private
    def ensure_admin
      redirect_to root_path, alert: "Not authorized" unless Current.user.admin?
    end

    def prepare_show_context
      load_connection_items
      build_sync_stats_maps
      build_connection_cards
    end

    def load_connection_items
      @instance_provider_configurations = Provider::Catalog.instance_configurations
      @plaid_us_configured = provider_configured?("plaid")
      @plaid_eu_configured = provider_configured?("plaid_eu")

      @plaid_items = Current.family.plaid_items.ordered.includes(:syncs, :plaid_accounts)
      @simplefin_items = Current.family.simplefin_items.ordered.includes(:syncs)
      @lunchflow_items = Current.family.lunchflow_items.ordered.includes(:syncs, :lunchflow_accounts)
      @enable_banking_items = Current.family.enable_banking_items.ordered.includes(:syncs)
      @coinstats_items = Current.family.coinstats_items.ordered.includes(:coinstats_accounts, :accounts, :syncs)
      @mercury_items = Current.family.mercury_items.ordered.includes(:syncs, :mercury_accounts)
      @coinbase_items = Current.family.coinbase_items.ordered.includes(:coinbase_accounts, :accounts, :syncs)
      @snaptrade_items = Current.family.snaptrade_items.ordered.includes(:syncs, :snaptrade_accounts)
      @indexa_capital_items = Current.family.indexa_capital_items.ordered.includes(:syncs, :indexa_capital_accounts)
    end

    def provider_configured?(provider_key)
      @instance_provider_configurations.any? do |config|
        config.provider_key.to_s == provider_key.to_s && config.configured?
      end
    end

    def build_connection_cards
      @connection_cards = Provider::Catalog.connection_definitions.filter_map do |definition|
        build_connection_card(definition)
      end

      @needs_attention_cards = cards_for_bucket("needs_attention")
      @connected_cards = cards_for_bucket("connected")
      @available_cards = cards_for_bucket("available")
      @summary_counts = {
        needs_attention: @needs_attention_cards.count,
        connected: @connected_cards.count,
        available: @available_cards.count,
        syncing: @connection_cards.count { |card| card[:syncing] }
      }
    end

    def cards_for_bucket(bucket)
      @connection_cards.select { |card| card[:bucket] == bucket }
    end

    def build_connection_card(definition)
      items = Array(instance_variable_get("@#{definition.collection_name}"))
      instance_enabled = instance_enabled_for?(definition)
      return nil if items.empty? && !instance_enabled && definition.requires_instance_config.present?

      attention = attention_details_for(definition.key, items)
      bucket = if attention.present?
        "needs_attention"
      elsif items.any?
        "connected"
      else
        "available"
      end

      primary_action = primary_action_for(definition, items, bucket, instance_enabled)

      {
        definition: definition,
        key: definition.key,
        title: definition.title,
        category: definition.category,
        maturity: definition.maturity,
        items: items,
        item_partial: definition.item_partial,
        panel_partial: definition.panel_partial,
        turbo_frame_id: definition.turbo_frame_id,
        show_item_collection: definition.show_item_collection,
        show_panel_when_connected: definition.show_panel_when_connected,
        panel_locals: definition.panel_locals || {},
        bucket: bucket,
        status_label: status_label_for(bucket, items, attention),
        status_tone: status_tone_for(bucket, items, attention),
        meta_text: meta_text_for(definition.key, items, bucket),
        syncing: items.any?(&:syncing?),
        open: selected_provider?(definition.key) || bucket == "needs_attention",
        primary_action_label: primary_action[:label],
        primary_action_path: primary_action[:path],
        primary_action_frame: primary_action[:frame],
        plaid_us_available: @plaid_us_configured,
        plaid_eu_available: @plaid_eu_configured
      }
    end

    def instance_enabled_for?(definition)
      return true if definition.requires_instance_config.blank?

      Array(definition.requires_instance_config).any? { |provider_key| provider_configured?(provider_key) }
    end

    def selected_provider?(provider_key)
      params[:provider].to_s == provider_key.to_s || (provider_key.to_s == "snaptrade" && params[:manage].present?)
    end

    def primary_action_for(definition, items, bucket, instance_enabled)
      if definition.key == "plaid"
        if instance_enabled
          region = @plaid_us_configured ? nil : "eu"
          return {
            label: items.any? ? "Connect another" : "Connect bank",
            path: new_plaid_item_path(origin: "connections", region: region),
            frame: "modal"
          }
        end

        return {
          label: "Manage",
          path: settings_providers_path(provider: definition.key, anchor: "provider-#{definition.key}"),
          frame: nil
        }
      end

      label = case bucket
      when "available" then "Connect"
      when "needs_attention" then "Fix"
      else "Manage"
      end

      {
        label: label,
        path: settings_providers_path(provider: definition.key, anchor: "provider-#{definition.key}"),
        frame: nil
      }
    end

    def status_label_for(bucket, items, attention)
      return "Syncing" if items.any?(&:syncing?)
      return attention[:label] if attention.present?

      bucket == "connected" ? "Connected" : "Available"
    end

    def status_tone_for(bucket, items, attention)
      return "primary" if items.any?(&:syncing?)
      return attention[:tone] if attention.present?

      bucket == "connected" ? "success" : "secondary"
    end

    def attention_details_for(provider_key, items)
      return if items.empty?

      case provider_key.to_s
      when "plaid"
        return { label: "Reconnect needed", tone: "warning" } if items.any?(&:requires_update?)
        return { label: "Connection issue", tone: "destructive" } if items.any? { |item| item.sync_error.present? }
      when "simplefin"
        return { label: "Reconnect needed", tone: "warning" } if items.any?(&:requires_update?)
        return { label: "Needs setup", tone: "warning" } if items.any? { |item| unlinked_accounts_count_for(provider_key, item) > 0 }
        return { label: "Sync issue", tone: "destructive" } if items.any? { |item| item.sync_error.present? || item.stale_sync_status[:stale] }
      when "lunchflow", "mercury"
        return { label: "Needs setup", tone: "warning" } if items.any? { |item| unlinked_accounts_count_for(provider_key, item) > 0 }
        return { label: "Sync issue", tone: "destructive" } if items.any? { |item| item.sync_error.present? }
      when "enable_banking"
        return { label: "Reconnect needed", tone: "warning" } if items.any?(&:requires_update?)
        return { label: "Session expired", tone: "warning" } if items.any? { |item| item.respond_to?(:session_expired?) && item.session_expired? }
        return { label: "Needs setup", tone: "warning" } if items.any? { |item| unlinked_accounts_count_for(provider_key, item) > 0 }
        return { label: "Sync issue", tone: "destructive" } if items.any? { |item| item.sync_error.present? }
      when "coinstats", "coinbase", "indexa_capital"
        return { label: "Reconnect needed", tone: "warning" } if items.any?(&:requires_update?)
        return { label: "Needs setup", tone: "warning" } if items.any? { |item| unlinked_accounts_count_for(provider_key, item) > 0 }
        return { label: "Sync issue", tone: "destructive" } if items.any? { |item| item.sync_error.present? }
      when "snaptrade"
        return { label: "Reconnect needed", tone: "warning" } if items.any?(&:requires_update?)
        return { label: "Finish setup", tone: "warning" } if items.any? { |item| !item.user_registered? || unlinked_accounts_count_for(provider_key, item) > 0 }
        return { label: "Sync issue", tone: "destructive" } if items.any? { |item| item.sync_error.present? }
      end
    end

    def meta_text_for(provider_key, items, bucket)
      return available_meta_for(provider_key) if items.empty?

      parts = []
      parts << helpers.pluralize(items.count, "connection")

      linked_accounts = items.sum do |item|
        item.respond_to?(:accounts) ? item.accounts.size : 0
      end
      parts << helpers.pluralize(linked_accounts, "linked account") if linked_accounts.positive?

      latest_sync = items.filter_map do |item|
        item.respond_to?(:last_synced_at) ? item.last_synced_at : nil
      end.compact.max
      parts << "Last synced #{helpers.time_ago_in_words(latest_sync)} ago" if latest_sync.present? && bucket != "needs_attention"

      parts.join(" · ")
    end

    def available_meta_for(provider_key)
      case provider_key.to_s
      when "plaid"
        "Connect a bank using your instance's Plaid setup"
      when "simplefin"
        "Use a setup token from SimpleFIN Bridge"
      when "lunchflow"
        "Add your Lunch Flow API credentials"
      when "enable_banking"
        "Save credentials and add a bank connection"
      when "coinstats"
        "Add an API key to connect crypto wallets"
      when "mercury"
        "Add your Mercury API token"
      when "coinbase"
        "Connect your Coinbase API keys"
      when "snaptrade"
        "Configure credentials and connect a brokerage"
      when "indexa_capital"
        "Add your Indexa Capital credentials"
      else
        "Ready to connect"
      end
    end

    def unlinked_accounts_count_for(provider_key, item)
      case provider_key.to_s
      when "simplefin"
        @simplefin_unlinked_count_map[item.id].to_i
      when "coinbase"
        @coinbase_unlinked_count_map[item.id].to_i
      else
        item.respond_to?(:unlinked_accounts_count) ? item.unlinked_accounts_count.to_i : 0
      end
    end

    # Builds sync stats maps for provider item partials
    def build_sync_stats_maps
      @simplefin_sync_stats_map = {}
      @simplefin_has_unlinked_map = {}
      @simplefin_unlinked_count_map = {}
      @simplefin_show_relink_map = {}
      @simplefin_duplicate_only_map = {}

      @simplefin_items.each do |item|
        latest_sync = item.syncs.ordered.first
        stats = latest_sync&.sync_stats || {}
        @simplefin_sync_stats_map[item.id] = stats
        @simplefin_has_unlinked_map[item.id] = item.family.accounts.listable_manual.exists?

        count = item.simplefin_accounts
          .left_joins(:account, :account_provider)
          .where(accounts: { id: nil }, account_providers: { id: nil })
          .count
        @simplefin_unlinked_count_map[item.id] = count

        manuals_exist = @simplefin_has_unlinked_map[item.id]
        sfa_any = item.simplefin_accounts.loaded? ? item.simplefin_accounts.any? : item.simplefin_accounts.exists?
        @simplefin_show_relink_map[item.id] = (count.to_i == 0 && manuals_exist && sfa_any)

        errors = Array(stats["errors"]).map { |entry| entry.is_a?(Hash) ? entry["message"] || entry[:message] : entry.to_s }
        @simplefin_duplicate_only_map[item.id] = errors.present? && errors.all? { |message| message.to_s.downcase.include?("duplicate upstream account detected") }
      rescue => e
        Rails.logger.warn("SimpleFin stats map build failed for item #{item.id}: #{e.class} - #{e.message}")
        @simplefin_sync_stats_map[item.id] = {}
        @simplefin_show_relink_map[item.id] = false
        @simplefin_duplicate_only_map[item.id] = false
      end

      @plaid_sync_stats_map = {}
      @plaid_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @plaid_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      @lunchflow_sync_stats_map = {}
      @lunchflow_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @lunchflow_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      @enable_banking_sync_stats_map = {}
      @enable_banking_latest_sync_error_map = {}
      @enable_banking_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @enable_banking_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
        @enable_banking_latest_sync_error_map[item.id] = latest_sync&.error
      end

      @coinstats_sync_stats_map = {}
      @coinstats_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @coinstats_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      @mercury_sync_stats_map = {}
      @mercury_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @mercury_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end

      @coinbase_sync_stats_map = {}
      @coinbase_unlinked_count_map = {}
      @coinbase_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @coinbase_sync_stats_map[item.id] = latest_sync&.sync_stats || {}

        count = item.coinbase_accounts
          .left_joins(:account_provider)
          .where(account_providers: { id: nil })
          .count
        @coinbase_unlinked_count_map[item.id] = count
      end

      @indexa_capital_sync_stats_map = {}
      @indexa_capital_items.each do |item|
        latest_sync = item.syncs.ordered.first
        @indexa_capital_sync_stats_map[item.id] = latest_sync&.sync_stats || {}
      end
    end
end
