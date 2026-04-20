class Settings::SecurityController < ApplicationController
  layout "settings"

  def show
    @user = Current.user
    @recent_login_activities = Current.user.login_activities.recent.limit(5)
    @mfa_enabled = Current.user.otp_required?
    @sso_identities = Current.user.oidc_identities
    @breadcrumbs = [
      [ "Home", root_path ],
      [ t(".title"), nil ]
    ]
  end
end
