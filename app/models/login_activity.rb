class LoginActivity < ApplicationRecord
  belongs_to :user

  scope :recent, -> { order(created_at: :desc) }
  scope :unusual, -> { where(unusual: true) }

  # Get the first N logins for a user to establish "usual" country
  def self.establish_usual_country_for(user, count: 3)
    countries = user.login_activities.order(:created_at).limit(count).pluck(:country).compact
    return nil if countries.empty?

    # Find the most frequent country
    countries.group_by(&:itself).values.max_by(&:size)&.first
  end

  # Check if a country is unusual for a user based on their first N logins
  def self.unusual_country?(user, country, baseline_count: 3)
    return false if country.blank?

    login_count = user.login_activities.count
    return false if login_count < baseline_count # Not enough data yet

    usual_country = establish_usual_country_for(user, count: baseline_count)
    return false if usual_country.blank?

    country != usual_country
  end

  # Record a login and check if it's unusual
  def self.record_login!(user:, ip_address:, user_agent:, country: nil, city: nil)
    # Determine country from IP if not provided
    country ||= country_from_ip(ip_address)
    city ||= city_from_ip(ip_address)

    # Check if this is an unusual login
    unusual = unusual_country?(user, country)

    # Create the login activity record
    login_activity = create!(
      user: user,
      ip_address: ip_address,
      user_agent: user_agent,
      country: country,
      city: city,
      unusual: unusual
    )

    # Send alert email if unusual
    if unusual
      UnusualLoginMailer.alert(login_activity).deliver_later
    end

    login_activity
  end

  private

    # Extract country from IP address using geocoder
    def self.country_from_ip(ip_address)
      return nil if ip_address.blank? || ip_address == "127.0.0.1" || ip_address.start_with?("192.168.") || ip_address.start_with?("10.")

      result = Geocoder.search(ip_address).first
      result&.country
    rescue StandardError => e
      Rails.logger.warn("Failed to geocode IP #{ip_address}: #{e.message}")
      nil
    end

    def self.city_from_ip(ip_address)
      return nil if ip_address.blank? || ip_address == "127.0.0.1" || ip_address.start_with?("192.168.") || ip_address.start_with?("10.")

      result = Geocoder.search(ip_address).first
      result&.city
    rescue StandardError => e
      Rails.logger.warn("Failed to geocode IP #{ip_address}: #{e.message}")
      nil
    end
end
