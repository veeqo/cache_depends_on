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
    has_many :auditors, as: :auditable

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

  context 'when model is destroyed' do
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

  describe 'absence of redundant invalidations' do
    let(:account) { Account.create! }

    subject { account }

    shared_examples 'absence of redundant invalidations' do
      specify 'model is touched only once' do
        expect(subject).to receive(:touch).once.and_call_original

        ActiveRecord::Base.transaction { update_multiple_dependants }
      end

      specify 'hook is called only once' do
        subject.singleton_class.class_eval do
          def after_cache_invalidation_hook; end

          after_cache_invalidation :after_cache_invalidation_hook
        end

        expect(subject).to receive(:after_cache_invalidation_hook)

        ActiveRecord::Base.transaction { update_multiple_dependants }
      end
    end

    context 'when association is one-to-many' do
      let!(:accountants) { 3.times.map { Accountant.create! account: account } }

      def update_multiple_dependants
        accountants.each(&:touch)
      end

      include_examples 'absence of redundant invalidations'
    end

    context 'when association is polymorphic one-to-many' do
      let!(:auditors) { 3.times.map { Auditor.create! auditable: account } }

      def update_multiple_dependants
        auditors.each(&:touch)
      end

      include_examples 'absence of redundant invalidations'
    end

    context 'when association is one-to-many-through' do
      let(:provider) { account.create_provider! }
      let!(:auditors) { 3.times.map { Auditor.create! auditable: provider } }

      def update_multiple_dependants
        auditors.each(&:touch)
      end

      include_examples 'absence of redundant invalidations'
    end

    context 'when cache depends on changed objects more than once' do
      let(:provider) { account.create_provider! }
      let!(:provider_auditors) { 3.times.map { Auditor.create! auditable: provider } }
      let!(:account_auditors) { 3.times.map { Auditor.create! auditable: account } }

      def update_multiple_dependants
        provider_auditors.each(&:touch)
        account_auditors.each(&:touch)
      end

      include_examples 'absence of redundant invalidations'
    end
  end

  describe 'dependence configuration' do
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
  end

  describe 'after_cache_invalidation callback' do
    let(:account) { Account.create! }
    let!(:provider) { Provider.create! account: account }

    before do
      [account, provider].each do |object|
        object.singleton_class.class_eval do
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

  describe 'associations with inverse_of option' do
    class CompanyAddress < ActiveRecord::Base
      belongs_to :company, inverse_of: :address
      has_many :company_employees, through: :company, source: :employees
    end

    class Company < ActiveRecord::Base
      has_many :employees, class_name: 'User'
      has_one :address, class_name: 'CompanyAddress', inverse_of: :company
    end

    class UserProfile < ActiveRecord::Base
      belongs_to :user, inverse_of: :profile
    end

    class UserRole < ActiveRecord::Base
      belongs_to :user, inverse_of: :roles
    end

    class User < ActiveRecord::Base
      belongs_to :company, inverse_of: :employees
      has_many :roles, class_name: 'UserRole'
      has_one :profile, class_name: 'UserProfile'
      has_one :company_address, through: :company, source: :address, inverse_of: :company_employees

      cache_depends_on :roles, :profile, :company, :company_address
    end

    let!(:company)         { Company.create! }
    let!(:company_address) { CompanyAddress.create! company: company }
    let!(:user)            { User.create! company: company }
    let!(:user_profile)    { UserProfile.create! user: user }
    let!(:user_role)       { UserRole.create! user: user }

    before { user.update_column(:updated_at, 1.day.ago) }

    shared_examples 'dependent entity updating' do
      let(:dependent_entity) { user }

      it 'updates dependent entity' do
        expect { entity.reload.update_attribute(:updated_at, Time.now) }.to change { dependent_entity.reload.updated_at }
      end
    end

    context 'when relation is has_many with inverse_of' do
      let(:entity) { user_role }

      it_behaves_like 'dependent entity updating'
    end

    context 'when relation is has_one with inverse_of' do
      let(:entity) { user_profile }

      it_behaves_like 'dependent entity updating'
    end

    context 'when relation is belongs_to with inverse_of' do
      let(:entity) { company }

      it_behaves_like 'dependent entity updating'
    end

    context 'when relation is has_one through another association with inverse_of' do
      let(:entity) { company_address }

      it_behaves_like 'dependent entity updating'
    end
  end
end
