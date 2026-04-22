class ProviderSettingsUpdater
  def self.call(raw_params)
    Provider::Factory.ensure_adapters_loaded

    valid_fields = {}
    Provider::ConfigurationRegistry.all.each do |config|
      config.fields.each do |field|
        valid_fields[field.setting_key.to_s] = field
      end
    end

    updated_fields = []

    Setting.transaction do
      raw_params.to_h.each do |param_key, param_value|
        field = valid_fields[param_key.to_s]
        next unless field

        value = param_value.to_s.strip
        value = nil if value.empty?
        next if field.secret && value == "********"

        key_str = field.setting_key.to_s
        if Setting.singleton_class.method_defined?("#{key_str}=")
          Setting.public_send("#{key_str}=", value)
        else
          Setting[key_str] = value
        end

        updated_fields << param_key.to_s
      end
    end

    reload_provider_configs(updated_fields)
    updated_fields
  end

  def self.reload_provider_configs(updated_fields)
    updated_provider_keys = Set.new

    updated_fields.each do |field_key|
      Provider::ConfigurationRegistry.all.each do |config|
        field = config.fields.find { |entry| entry.setting_key.to_s == field_key.to_s }
        if field
          updated_provider_keys.add(field.provider_key)
          break
        end
      end
    end

    updated_provider_keys.each do |provider_key|
      adapter_class = Provider::ConfigurationRegistry.get_adapter_class(provider_key)
      adapter_class&.reload_configuration
    end
  end
end
