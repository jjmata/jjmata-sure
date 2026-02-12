require "test_helper"

class LoginActivityTest < ActiveSupport::TestCase
  def setup
    @user = users(:family_member)
  end

  test "should create login activity" do
    assert_difference "LoginActivity.count", 1 do
      LoginActivity.create!(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        country: "US"
      )
    end
  end

  test "should detect unusual country after baseline logins" do
    # Create 3 baseline logins from US
    3.times do
      LoginActivity.create!(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        country: "US"
      )
    end

    # Check that login from a different country is unusual
    assert LoginActivity.unusual_country?(@user, "CA")
  end

  test "should not detect unusual country with insufficient baseline" do
    # Create only 2 logins (below baseline of 3)
    2.times do
      LoginActivity.create!(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        country: "US"
      )
    end

    # Should not detect as unusual since we don't have enough baseline data
    assert_not LoginActivity.unusual_country?(@user, "CA")
  end

  test "should not detect unusual country for same country" do
    # Create 3 baseline logins from US
    3.times do
      LoginActivity.create!(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        country: "US"
      )
    end

    # Login from same country should not be unusual
    assert_not LoginActivity.unusual_country?(@user, "US")
  end

  test "should establish usual country from first logins" do
    # Create 3 logins from US
    3.times do
      LoginActivity.create!(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        country: "US"
      )
    end

    usual_country = LoginActivity.establish_usual_country_for(@user)
    assert_equal "US", usual_country
  end

  test "record_login! should mark unusual login" do
    # Create baseline logins from US
    3.times do
      LoginActivity.create!(
        user: @user,
        ip_address: "192.168.1.1",
        user_agent: "Mozilla/5.0",
        country: "US",
        unusual: false
      )
    end

    # Mock geocoder to avoid external API call
    Geocoder::Lookup::Test.add_stub(
      "203.0.113.1", [
        {
          "country" => "CA",
          "city" => "Toronto"
        }
      ]
    )

    # Record a login from a different country
    login = LoginActivity.record_login!(
      user: @user,
      ip_address: "203.0.113.1",
      user_agent: "Mozilla/5.0",
      country: "CA"
    )

    assert login.unusual?
  end
end
