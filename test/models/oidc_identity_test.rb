require "test_helper"

class OidcIdentityTest < ActiveSupport::TestCase
  setup do
    @user = users(:family_admin)
    @oidc_identity = oidc_identities(:bob_google)
  end

  test "belongs to user" do
    assert_equal @user, @oidc_identity.user
  end

  test "validates presence of provider" do
    @oidc_identity.provider = nil
    assert_not @oidc_identity.valid?
    assert_includes @oidc_identity.errors[:provider], "can't be blank"
  end

  test "validates presence of uid" do
    @oidc_identity.uid = nil
    assert_not @oidc_identity.valid?
    assert_includes @oidc_identity.errors[:uid], "can't be blank"
  end

  test "validates presence of user_id" do
    @oidc_identity.user_id = nil
    assert_not @oidc_identity.valid?
    assert_includes @oidc_identity.errors[:user_id], "can't be blank"
  end

  test "validates uniqueness of uid scoped to provider" do
    duplicate = OidcIdentity.new(
      user: users(:family_member),
      provider: @oidc_identity.provider,
      uid: @oidc_identity.uid
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:uid], "has already been taken"
  end

  test "allows same uid for different providers" do
    different_provider = OidcIdentity.new(
      user: users(:family_member),
      provider: "different_provider",
      uid: @oidc_identity.uid
    )

    assert different_provider.valid?
  end

  test "records authentication timestamp" do
    old_timestamp = @oidc_identity.last_authenticated_at
    travel_to 1.hour.from_now do
      @oidc_identity.record_authentication!
      assert @oidc_identity.last_authenticated_at > old_timestamp
    end
  end

  test "creates from omniauth hash" do
    auth = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google-123456",
      info: {
        email: "test@example.com",
        name: "Test User",
        first_name: "Test",
        last_name: "User"
      }
    })

    identity = OidcIdentity.create_from_omniauth(auth, @user)

    assert identity.persisted?
    assert_equal "google_oauth2", identity.provider
    assert_equal "google-123456", identity.uid
    assert_equal "test@example.com", identity.info["email"]
    assert_equal "Test User", identity.info["name"]
    assert_equal @user, identity.user
    assert_not_nil identity.last_authenticated_at
  end

  test "creates from omniauth hash and attaches profile image when provided" do
    image_response = fake_image_response(content_type: "image/png", body: "png-bytes")
    @oidc_identity.stubs(:fetch_profile_image).returns(image_response)

    auth = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google-123456",
      info: {
        email: "test@example.com",
        name: "Test User",
        first_name: "Test",
        last_name: "User",
        image: "https://lh3.googleusercontent.com/avatar.png"
      }
    })

    @oidc_identity.sync_profile_image_from_auth(auth)

    assert @user.profile_image.attached?
    assert_equal "image/png", @user.profile_image.blob.content_type
  end

  test "sync_user_attributes does not replace an existing profile image" do
    @user.profile_image.attach(
      io: StringIO.new("existing-avatar"),
      filename: "existing.jpg",
      content_type: "image/jpeg"
    )

    auth = OmniAuth::AuthHash.new({
      provider: @oidc_identity.provider,
      uid: @oidc_identity.uid,
      info: {
        email: @user.email,
        name: "Updated User",
        first_name: "Updated",
        last_name: "User",
        image: "https://lh3.googleusercontent.com/new-avatar.png"
      }
    })

    @oidc_identity.expects(:fetch_profile_image).never

    original_blob_id = @user.profile_image.blob.id

    @oidc_identity.sync_user_attributes!(auth)

    @user.reload
    assert @user.profile_image.attached?
    assert_equal original_blob_id, @user.profile_image.blob.id
  end

  test "does not download avatar for non-google host" do
    auth = OmniAuth::AuthHash.new({
      provider: "google_oauth2",
      uid: "google-123456",
      info: {
        image: "https://example.com/avatar.png"
      }
    })

    @oidc_identity.expects(:fetch_profile_image).never

    @oidc_identity.sync_profile_image_from_auth(auth)

    assert_not @user.profile_image.attached?
  end

  private

    def fake_image_response(content_type:, body:)
      response = Object.new
      response.define_singleton_method(:is_a?) do |klass|
        klass == Net::HTTPSuccess
      end
      response.define_singleton_method(:[]) do |header_name|
        header_name == "Content-Type" ? content_type : nil
      end
      response.define_singleton_method(:body) { body }
      response
    end
end
