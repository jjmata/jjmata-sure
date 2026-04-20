require "test_helper"

class UnusualLoginMailerTest < ActionMailer::TestCase
  def setup
    @user = users(:family_admin)
    @login_activity = LoginActivity.create!(
      user: @user,
      ip_address: "203.0.113.1",
      user_agent: "Mozilla/5.0",
      country: "CA",
      city: "Toronto",
      unusual: true
    )
  end

  test "alert email" do
    email = UnusualLoginMailer.alert(@login_activity)

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [ @user.email ], email.to
    assert_match "Unusual login", email.subject
    assert_match @user.first_name, email.body.to_s
  end
end
