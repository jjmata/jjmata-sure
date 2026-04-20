class UnusualLoginMailer < ApplicationMailer
  def alert(login_activity)
    @user = login_activity.user
    @login_activity = login_activity
    @subject = t(".subject", product_name: product_name)

    mail to: @user.email, subject: @subject
  end
end
