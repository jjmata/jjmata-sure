class FamilyResetJob < ApplicationJob
  queue_as :low_priority

  def perform(family, load_sample_data_for_email: nil)
    # Delete all family data except users
    ActiveRecord::Base.transaction do
      # Delete accounts and related data
      family.accounts.destroy_all
      family.categories.destroy_all
      family.tags.destroy_all
      family.merchants.destroy_all
      family.recurring_transactions.destroy_all
      family.rules.destroy_all
      family.budgets.destroy_all

      # Delete imports and exports
      family.imports.destroy_all
      family.family_exports.destroy_all

      # Delete provider connections
      family.plaid_items.destroy_all
      family.simplefin_items.destroy_all
      family.lunchflow_items.destroy_all
      family.enable_banking_items.destroy_all
      family.coinbase_items.destroy_all
      family.coinstats_items.destroy_all

      # Delete invitations and usage data
      family.invitations.destroy_all
      family.llm_usages.destroy_all
    end

    if load_sample_data_for_email.present?
      Demo::Generator.new.generate_new_user_data_for!(family.reload, email: load_sample_data_for_email)
    else
      family.sync_later
    end
  end
end
