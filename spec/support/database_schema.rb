ActiveRecord::Schema.define version: 0 do
  create_table(:accounts) do |t|
    t.belongs_to :provider
    t.timestamps null: false
  end

  create_table(:providers) do |t|
    t.belongs_to :payment_gate
    t.timestamps null: false
  end

  create_table(:personal_data) do |t|
    t.belongs_to :account
    t.timestamps null: false
  end

  create_table(:accountants) do |t|
    t.belongs_to :account
    t.timestamps null: false
  end

  create_table(:payment_gates) do |t|
    t.timestamps null: false
  end

  create_table(:auditors) do |t|
    t.references :auditable, polymorphic: true
    t.timestamps null: false
  end

  create_table(:transactions) do |t|
    t.belongs_to :payer
    t.belongs_to :account
    t.timestamps null: false
  end

  create_table(:payers) do |t|
    t.timestamps null: false
  end
end
