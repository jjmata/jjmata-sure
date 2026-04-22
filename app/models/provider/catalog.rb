class Provider::Catalog
  Definition = Struct.new(
    :key,
    :title,
    :category,
    :maturity,
    :panel_partial,
    :item_partial,
    :collection_name,
    :turbo_frame_id,
    :show_item_collection,
    :show_panel_when_connected,
    :panel_locals,
    :requires_instance_config,
    keyword_init: true
  )

  INSTANCE_CONFIG_KEYS = %w[plaid plaid_eu].freeze

  CONNECTION_DEFINITIONS = [
    Definition.new(
      key: "plaid",
      title: "Plaid",
      category: "Banks & cards",
      panel_partial: nil,
      item_partial: "plaid_items/plaid_item",
      collection_name: :plaid_items,
      turbo_frame_id: nil,
      show_item_collection: true,
      show_panel_when_connected: false,
      panel_locals: {},
      requires_instance_config: %w[plaid plaid_eu]
    ),
    Definition.new(
      key: "simplefin",
      title: "SimpleFIN",
      category: "Banks & cards",
      panel_partial: "settings/providers/simplefin_panel",
      item_partial: "simplefin_items/simplefin_item",
      collection_name: :simplefin_items,
      turbo_frame_id: "simplefin-providers-panel",
      show_item_collection: true,
      show_panel_when_connected: false,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "lunchflow",
      title: "Lunch Flow",
      category: "Banks & cards",
      panel_partial: "settings/providers/lunchflow_panel",
      item_partial: "lunchflow_items/lunchflow_item",
      collection_name: :lunchflow_items,
      turbo_frame_id: "lunchflow-providers-panel",
      show_item_collection: true,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "enable_banking",
      title: "Enable Banking",
      category: "Banks & cards",
      maturity: "Beta",
      panel_partial: "settings/providers/enable_banking_panel",
      item_partial: "enable_banking_items/enable_banking_item",
      collection_name: :enable_banking_items,
      turbo_frame_id: "enable_banking-providers-panel",
      show_item_collection: false,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "coinstats",
      title: "CoinStats",
      category: "Crypto",
      maturity: "Beta",
      panel_partial: "settings/providers/coinstats_panel",
      item_partial: "coinstats_items/coinstats_item",
      collection_name: :coinstats_items,
      turbo_frame_id: "coinstats-providers-panel",
      show_item_collection: true,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "mercury",
      title: "Mercury",
      category: "Business banking",
      maturity: "Beta",
      panel_partial: "settings/providers/mercury_panel",
      item_partial: "mercury_items/mercury_item",
      collection_name: :mercury_items,
      turbo_frame_id: "mercury-providers-panel",
      show_item_collection: true,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "coinbase",
      title: "Coinbase",
      category: "Crypto",
      maturity: "Beta",
      panel_partial: "settings/providers/coinbase_panel",
      item_partial: "coinbase_items/coinbase_item",
      collection_name: :coinbase_items,
      turbo_frame_id: "coinbase-providers-panel",
      show_item_collection: false,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "snaptrade",
      title: "SnapTrade",
      category: "Investments",
      maturity: "Beta",
      panel_partial: "settings/providers/snaptrade_panel",
      item_partial: "snaptrade_items/snaptrade_item",
      collection_name: :snaptrade_items,
      turbo_frame_id: "snaptrade-providers-panel",
      show_item_collection: true,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    ),
    Definition.new(
      key: "indexa_capital",
      title: "Indexa Capital",
      category: "Investments",
      maturity: "Alpha",
      panel_partial: "settings/providers/indexa_capital_panel",
      item_partial: "indexa_capital_items/indexa_capital_item",
      collection_name: :indexa_capital_items,
      turbo_frame_id: "indexa_capital-providers-panel",
      show_item_collection: true,
      show_panel_when_connected: true,
      panel_locals: {},
      requires_instance_config: nil
    )
  ].freeze

  def self.connection_definitions
    CONNECTION_DEFINITIONS
  end

  def self.instance_configurations
    Provider::Factory.ensure_adapters_loaded
    Provider::ConfigurationRegistry.all.select do |configuration|
      instance_config_key?(configuration.provider_key)
    end
  end

  def self.instance_config_key?(provider_key)
    INSTANCE_CONFIG_KEYS.include?(provider_key.to_s)
  end
end
