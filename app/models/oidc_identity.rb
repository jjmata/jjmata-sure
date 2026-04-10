require "net/http"
require "stringio"

class OidcIdentity < ApplicationRecord
  GOOGLE_AVATAR_HOST_SUFFIX = "googleusercontent.com".freeze

  belongs_to :user

  validates :provider, presence: true
  validates :uid, presence: true, uniqueness: { scope: :provider }
  validates :user_id, presence: true

  # Update the last authenticated timestamp
  def record_authentication!
    update!(last_authenticated_at: Time.current)
  end

  # Sync user attributes from IdP on each login
  # Updates stored identity info and syncs name to user (not email - that's identity)
  def sync_user_attributes!(auth)
    # Extract groups from claims (various common claim names)
    groups = extract_groups(auth)

    # Update stored identity info with latest from IdP
    update!(info: {
      email: auth.info&.email,
      name: auth.info&.name,
      first_name: auth.info&.first_name,
      last_name: auth.info&.last_name,
      groups: groups
    })

    # Sync name to user if provided (keep existing if IdP doesn't provide)
    user.update!(
      first_name: auth.info&.first_name.presence || user.first_name,
      last_name: auth.info&.last_name.presence || user.last_name
    )

    sync_profile_image_from_auth(auth)

    # Apply role mapping based on group membership
    apply_role_mapping!(groups)
  end

  # Extract groups from various common IdP claim formats
  def extract_groups(auth)
    # Try various common group claim locations
    groups = auth.extra&.raw_info&.groups ||
             auth.extra&.raw_info&.[]("groups") ||
             auth.extra&.raw_info&.[]("Group") ||
             auth.info&.groups ||
             auth.extra&.raw_info&.[]("http://schemas.microsoft.com/ws/2008/06/identity/claims/groups") ||
             auth.extra&.raw_info&.[]("cognito:groups") ||
             []

    # Normalize to array of strings
    Array(groups).map(&:to_s)
  end

  # Apply role mapping based on IdP group membership
  def apply_role_mapping!(groups)
    config = provider_config
    return unless config.present?

    role_mapping = config.dig(:settings, :role_mapping) || config.dig(:settings, "role_mapping")
    return unless role_mapping.present?

    # Check roles in order of precedence (highest to lowest)
    %w[super_admin admin member].each do |role|
      mapped_groups = role_mapping[role] || role_mapping[role.to_sym] || []
      mapped_groups = Array(mapped_groups)

      # Check if user is in any of the mapped groups
      if mapped_groups.include?("*") || (mapped_groups & groups).any?
        # Only update if different to avoid unnecessary writes
        user.update!(role: role) unless user.role == role
        Rails.logger.info("[SSO] Applied role mapping: user_id=#{user.id} role=#{role} groups=#{groups}")
        return
      end
    end
  end

  # Extract and store relevant info from OmniAuth auth hash
  def self.create_from_omniauth(auth, user)
    # Extract issuer from OIDC auth response if available
    issuer = auth.extra&.raw_info&.iss || auth.extra&.raw_info&.[]("iss")

    identity = create!(
      user: user,
      provider: auth.provider,
      uid: auth.uid,
      issuer: issuer,
      info: {
        email: auth.info&.email,
        name: auth.info&.name,
        first_name: auth.info&.first_name,
        last_name: auth.info&.last_name
      },
      last_authenticated_at: Time.current
    )

    identity.sync_profile_image_from_auth(auth)
    identity
  end

  # Find the configured provider for this identity
  def provider_config
    Rails.configuration.x.auth.sso_providers&.find { |p| p[:name] == provider || p[:id] == provider }
  end

  # Validate that the stored issuer matches the configured provider's issuer
  # Returns true if valid, false if mismatch (security concern)
  def issuer_matches_config?
    return true if issuer.blank? # Backward compatibility for old records

    config = provider_config
    return true if config.blank? || config[:issuer].blank? # No config to validate against

    issuer == config[:issuer]
  end

  def sync_profile_image_from_auth(auth)
    return if user.profile_image.attached?

    image_url = auth.info&.image.presence || auth.extra&.raw_info&.picture.presence || auth.extra&.raw_info&.[]("picture")
    return if image_url.blank?

    uri = URI.parse(image_url)
    return unless uri.is_a?(URI::HTTPS)
    return unless google_avatar_host?(uri)

    response = fetch_profile_image(uri)
    return unless response.is_a?(Net::HTTPSuccess)

    content_type = response["Content-Type"]&.split(";")&.first&.downcase
    return unless content_type.in?(%w[image/jpeg image/png])
    return if response.body.to_s.bytesize > 10.megabytes

    user.profile_image.attach(
      io: StringIO.new(response.body),
      filename: "#{provider}-avatar-#{uid}.#{content_type == 'image/png' ? 'png' : 'jpg'}",
      content_type: content_type
    )
  rescue StandardError => error
    Rails.logger.warn("[SSO] Could not sync profile image for oidc_identity=#{id}: #{error.class} #{error.message}")
  end

  private

    def google_avatar_host?(uri)
      host = uri.host.to_s.downcase
      host == GOOGLE_AVATAR_HOST_SUFFIX || host.end_with?(".#{GOOGLE_AVATAR_HOST_SUFFIX}")
    end

    def fetch_profile_image(uri)
      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: true,
        open_timeout: 5,
        read_timeout: 5,
        write_timeout: 5
      ) do |http|
        request = Net::HTTP::Get.new(uri)
        http.request(request)
      end
    end
end
