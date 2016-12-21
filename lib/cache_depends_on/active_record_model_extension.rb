require 'active_record'
require 'active_support/concern'

module CacheDependsOn
  module ActiveRecordModelExtension
    extend ActiveSupport::Concern

    included do
      cattr_accessor(:invalidates_cache_of) { [] }

      after_commit { invalidate_marked_dependent_caches }

      after_touch { invalidate_dependent_caches_after_outermost_transaction }

      after_save { invalidate_dependent_caches_after_outermost_transaction }

      after_destroy { invalidate_dependent_caches_after_outermost_transaction }

      define_model_callbacks :cache_invalidation
    end

    def invalidate_after_outermost_transaction
      self.marked_to_be_invalidated_after_outermost_transaction = true
      invalidate_dependent_caches_after_outermost_transaction
    end

    def invalidate_cache
      if marked_to_be_invalidated_after_outermost_transaction
        self.marked_to_be_invalidated_after_outermost_transaction = false
        touch
      end
    end

    protected

    attr_accessor :marked_to_be_invalidated_after_outermost_transaction

    def invalidate_dependent_caches_after_outermost_transaction
      invalidates_cache_of.select(&:collection?).each { |association| __send__(association.name).each(&:invalidate_after_outermost_transaction) }
      invalidates_cache_of.reject(&:collection?).each { |association| __send__(association.name).try(:invalidate_after_outermost_transaction) }
    end

    def invalidate_marked_dependent_caches
      run_callbacks(:cache_invalidation) do
        invalidates_cache_of.select(&:collection?).each { |association| __send__(association.name).each(&:invalidate_cache) }
        invalidates_cache_of.reject(&:collection?).each { |association| __send__(association.name).try(:invalidate_cache) }
      end
    end
  end
end
