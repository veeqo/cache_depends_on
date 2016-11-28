require 'spec_helper'

describe CacheDependsOn, '#cache_depends_on' do
  class PersonalDatum < ActiveRecord::Base
    belongs_to :account
  end

  class Accountant < ActiveRecord::Base
    belongs_to :account
  end

  class PaymentGate < ActiveRecord::Base
    has_many :providers
  end

  class Provider < ActiveRecord::Base
    has_one :account
    belongs_to :payment_gate

    cache_depends_on :payment_gate
  end

  class Auditor < ActiveRecord::Base
    belongs_to :auditable, polymorphic: true
  end

  class Payer < ActiveRecord::Base
    has_many :transactions
    has_many :accounts, through: :transactions
  end

  class Transaction < ActiveRecord::Base
    belongs_to :payer
    belongs_to :account
  end

  class Account < ActiveRecord::Base
    belongs_to :provider
    has_one :personal_datum
    has_many :accountants
    has_many :auditors, as: :auditable
    has_many :transactions
    has_many :payers, through: :transactions

    cache_depends_on :provider, :personal_datum, :accountants, :auditors, :payers
  end

  shared_examples 'cascade cache invalidation' do
    context 'when the association is one-to-one' do
      context 'when the association is :belongs_to' do
        let(:provider) { Provider.create! }
        let!(:account) { Account.create! provider: provider }

        subject { provider }

        it 'updates dependent entity' do
          expect { update_subject }.to change { account.reload.updated_at }
        end
      end

      context 'when the association is :has_one' do
        let(:account) { Account.create! }
        let(:personal_datum) { PersonalDatum.create! account: account }

        subject { personal_datum }

        it 'updates dependent entity' do
          expect { update_subject }.to change { account.reload.updated_at }
        end

        context 'when dependent association is nil' do
          before { personal_datum.update_attribute(:account_id, nil) }

          it 'does not raise exception' do
            expect { update_subject }.not_to raise_exception
          end
        end
      end
    end

    context 'when the association is one-to-many' do
      let(:account) { Account.create! }
      let(:accountant) { Accountant.create! account: account }

      subject { accountant }

      it 'updates dependent entity' do
        expect { update_subject }.to change { account.reload.updated_at }
      end

      context 'when dependent association is nil' do
        before { accountant.update_attribute(:account_id, nil) }

        it 'does not raise exception' do
          expect { update_subject }.not_to raise_exception
        end
      end
    end

    context 'when the association is many-to-one' do
      let(:payment_gate) { PaymentGate.create! }
      let!(:providers) { 2.times.map { Provider.create! payment_gate: payment_gate } }

      subject { payment_gate }

      it 'updates all dependants' do
        providers.each do |provider|
          expect { update_subject }.to change { provider.reload.updated_at }
        end
      end
    end

    context 'when association is polymorphic' do
      let(:account) { Account.create! }
      let!(:auditor) { Auditor.create! auditable: account }

      subject { auditor }

      it 'updates polymorphic dependant' do
        expect { update_subject }.to change { account.reload.updated_at }
      end
    end

    context 'when association is has-many-through' do
      let(:accounts) { 2.times.map { Account.create! } }
      let(:payer) { Payer.create! }

      before do
        accounts.each { |account| Transaction.create! payer: payer, account: account }
      end

      subject { payer }

      it 'updates all dependants' do
        accounts.each do |account|
          expect { update_subject }.to change { account.reload.updated_at }
        end
      end
    end

    context 'when it is a multi-level association' do
      let(:account) { Account.create! }
      let(:payment_gate) { PaymentGate.create! }
      let(:provider) { Provider.create! account: account, payment_gate: payment_gate }

      subject { payment_gate }

      it 'updates dependants all the way up to the root of the chain' do
        expect { update_subject }.to change { provider.reload.updated_at }
        expect { update_subject }.to change { account.reload.updated_at }
      end
    end

    describe 'hooks triggering' do
      let(:account) { Account.create! }
      let!(:provider) { Provider.create! account: account }

      subject { provider }

      before do
        Account.class_eval do
          def after_update_hook; end
          after_update :after_update_hook
        end
      end

      it 'does not trigger after_update hook of dependent entities' do
        expect(account).not_to receive(:after_update_hook)
        update_subject
      end
    end
  end

  context 'when model is touched' do
    def update_subject
      subject.reload.touch
    end

    include_examples 'cascade cache invalidation'
  end

  context 'when model is updated' do
    def update_subject
      subject.reload.update_attribute :updated_at, Time.now
    end

    include_examples 'cascade cache invalidation'
  end

  context 'when model is created' do
    def create_subject
      subject.save!
    end

    context 'when the association is one-to-one' do
      context 'when the association is :has_one' do
        let(:account) { Account.create! }

        subject { PersonalDatum.new(account: account) }

        it 'updates dependent entity' do
          expect { create_subject }.to change { account.reload.updated_at }
        end
      end
    end

    context 'when the association is one-to-many' do
      let(:account) { Account.create! }

      subject { Accountant.new(account: account) }

      it 'updates dependent entity' do
        expect { create_subject }.to change { account.reload.updated_at }
      end
    end
  end

  context 'when model is destroy' do
    def destroy_subject
      subject.destroy
    end

    context 'when the association is one-to-one' do
      context 'when the association is :has_one' do
        let(:account) { Account.create! }
        let!(:personal_datum) { PersonalDatum.create!(account: account) }

        subject { personal_datum }

        it 'updates dependent entity' do
          expect { destroy_subject }.to change { account.reload.updated_at }
        end
      end
    end

    context 'when the association is one-to-many' do
      let(:account) { Account.create! }
      let!(:accountant) { Accountant.create!(account: account) }

      subject { accountant }

      it 'updates dependent entity' do
        expect { destroy_subject }.to change { account.reload.updated_at }
      end
    end
  end

  context 'when association is not found' do
    it 'raises a correspondent error' do
      expect do
        Account.class_eval do
          cache_depends_on :abrakadabra
        end
      end.to raise_error(CacheDependsOn::AssociationNotFound, 'association abrakadabra was not found in Account')
    end
  end

  context 'when reverse association is not found' do
    it 'raises a correspondent error' do
      expect do
        Account.class_eval do
          has_many :payment_gates

          cache_depends_on :payment_gates
        end
      end.to raise_error(CacheDependsOn::ReverseAssociationNotFound, 'reverse association of Account was not found in PaymentGate')
    end
  end

  describe 'after_cache_invalidation callback' do
    let(:account) { Account.create! }
    let!(:provider) { Provider.create! account: account }

    before do
      [Account, Provider].each do |klass|
        klass.class_eval do
          def after_cache_invalidation_hook; end
          def another_after_cache_invalidation_hook; end

          after_cache_invalidation :after_cache_invalidation_hook
          after_cache_invalidation :another_after_cache_invalidation_hook
        end
      end
    end

    it 'calls all given blocks upon cache invalidation' do
      expect(provider).to receive(:after_cache_invalidation_hook)
      expect(provider).to receive(:another_after_cache_invalidation_hook)

      expect(account).to receive(:after_cache_invalidation_hook)
      expect(account).to receive(:another_after_cache_invalidation_hook)

      provider.touch
    end
  end
end
