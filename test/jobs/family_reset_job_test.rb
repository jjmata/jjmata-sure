require "test_helper"

class FamilyResetJobTest < ActiveJob::TestCase
  setup do
    @family = families(:dylan_family)
    @plaid_provider = mock
    Provider::Registry.stubs(:plaid_provider_for_region).returns(@plaid_provider)
  end

  test "resets family data successfully" do
    initial_account_count = @family.accounts.count
    initial_category_count = @family.categories.count

    # Family should have existing data
    assert initial_account_count > 0
    assert initial_category_count > 0

    # Don't expect Plaid removal calls since we're using fixtures without setup
    @plaid_provider.stubs(:remove_item)

    FamilyResetJob.perform_now(@family)

    # All data should be removed
    assert_equal 0, @family.accounts.reload.count
    assert_equal 0, @family.categories.reload.count
  end

  test "resets family data even when Plaid credentials are invalid" do
    # Use existing plaid item from fixtures
    plaid_item = plaid_items(:one)
    assert_equal @family, plaid_item.family

    initial_plaid_count = @family.plaid_items.count
    assert initial_plaid_count > 0

    # Simulate invalid Plaid credentials error
    error_response = {
      "error_code" => "INVALID_API_KEYS",
      "error_message" => "invalid client_id or secret provided"
    }.to_json

    plaid_error = Plaid::ApiError.new(code: 400, response_body: error_response)
    @plaid_provider.expects(:remove_item).raises(plaid_error)

    # Job should complete successfully despite the Plaid error
    assert_nothing_raised do
      FamilyResetJob.perform_now(@family)
    end

    # PlaidItem should be deleted
    assert_equal 0, @family.plaid_items.reload.count
  end

  test "deletes all family data including recurring transactions and provider connections" do
    # Create test data for all family associations
    # Core financial data
    tag = @family.tags.create!(name: "Test Tag", color: "#FF0000")
    merchant = @family.merchants.create!(name: "Test Merchant")
    category = @family.categories.create!(name: "Test Category", color: "#00FF00")
    recurring_transaction = @family.recurring_transactions.create!(
      name: "Test Recurring",
      amount: 100,
      currency: "USD",
      expected_day_of_month: 15,
      status: "active"
    )
    rule = @family.rules.create!(
      name: "Test Rule",
      action: "categorize",
      conditions: { field: "name", operator: "contains", value: "test" }
    )
    budget = @family.budgets.create!(name: "Test Budget", currency: "USD")

    # Imports and exports
    import = @family.imports.create!(
      type: "Import::Csv",
      status: "pending",
      raw_file_str: "test,data"
    )
    family_export = @family.family_exports.create!(
      status: "pending"
    )

    # Provider connections
    simplefin_item = @family.simplefin_items.create!(
      credential: "test_credential"
    )
    lunchflow_item = @family.lunchflow_items.create!(
      credential: "test_credential"
    )

    # User-related data
    invitation = @family.invitations.create!(
      email: "test@example.com",
      role: "member",
      token: SecureRandom.hex
    )

    # Verify data exists before reset
    assert @family.tags.exists?(tag.id)
    assert @family.merchants.exists?(merchant.id)
    assert @family.categories.exists?(category.id)
    assert @family.recurring_transactions.exists?(recurring_transaction.id)
    assert @family.rules.exists?(rule.id)
    assert @family.budgets.exists?(budget.id)
    assert @family.imports.exists?(import.id)
    assert @family.family_exports.exists?(family_export.id)
    assert @family.simplefin_items.exists?(simplefin_item.id)
    assert @family.lunchflow_items.exists?(lunchflow_item.id)
    assert @family.invitations.exists?(invitation.id)

    # Mock Plaid provider to avoid external calls
    @plaid_provider.stubs(:remove_item)

    # Perform reset
    FamilyResetJob.perform_now(@family)

    # Verify ALL data is deleted
    # Core financial data
    assert_equal 0, @family.accounts.reload.count
    assert_equal 0, @family.tags.reload.count
    assert_equal 0, @family.merchants.reload.count
    assert_equal 0, @family.categories.reload.count
    assert_equal 0, @family.recurring_transactions.reload.count
    assert_equal 0, @family.rules.reload.count
    assert_equal 0, @family.budgets.reload.count

    # Imports and exports
    assert_equal 0, @family.imports.reload.count
    assert_equal 0, @family.family_exports.reload.count

    # Provider connections
    assert_equal 0, @family.plaid_items.reload.count
    assert_equal 0, @family.simplefin_items.reload.count
    assert_equal 0, @family.lunchflow_items.reload.count

    # User-related data
    assert_equal 0, @family.invitations.reload.count

    # Verify users are NOT deleted
    assert @family.users.exists?
  end

  test "deletes enable_banking, coinbase, and coinstats items if present" do
    # These providers might not always have fixtures, so we create them directly
    enable_banking_item = @family.enable_banking_items.create!(
      credential: "test_credential"
    ) if @family.respond_to?(:enable_banking_items)

    coinbase_item = @family.coinbase_items.create!(
      credential: "test_credential"
    ) if @family.respond_to?(:coinbase_items)

    coinstats_item = @family.coinstats_items.create!(
      credential: "test_credential"
    ) if @family.respond_to?(:coinstats_items)

    # Mock Plaid provider
    @plaid_provider.stubs(:remove_item)

    # Perform reset
    FamilyResetJob.perform_now(@family)

    # Verify provider items are deleted (if they exist)
    assert_equal 0, @family.enable_banking_items.reload.count if @family.respond_to?(:enable_banking_items)
    assert_equal 0, @family.coinbase_items.reload.count if @family.respond_to?(:coinbase_items)
    assert_equal 0, @family.coinstats_items.reload.count if @family.respond_to?(:coinstats_items)
  end

  test "deletes llm_usages if present" do
    # Create LLM usage record if the association exists
    if @family.respond_to?(:llm_usages)
      llm_usage = @family.llm_usages.create!(
        input_tokens: 100,
        output_tokens: 50,
        model: "test-model"
      )

      assert @family.llm_usages.exists?(llm_usage.id)
    end

    # Mock Plaid provider
    @plaid_provider.stubs(:remove_item)

    # Perform reset
    FamilyResetJob.perform_now(@family)

    # Verify LLM usages are deleted
    assert_equal 0, @family.llm_usages.reload.count if @family.respond_to?(:llm_usages)
  end
end
