require 'active_record'
require 'active_support/concern'

module CacheDependsOn
  module ActiveRecordModelExtension
    extend ActiveSupport::Concern

    included do
      cattr_accessor(:invalidates_cache_of) { [] }

      after_commit { invalidate_dependent_caches }

      define_model_callbacks :cache_invalidation
    end

    def invalidate_cache
      touch
    end

    def invalidate_dependent_caches
      run_callbacks(:cache_invalidation) do
        invalidates_cache_of.select(&:collection?).each { |association| __send__(association.name).each(&:invalidate_cache) }
        invalidates_cache_of.reject(&:collection?).each { |association| __send__(association.name).try(:invalidate_cache) }
      end
    end
  end
end
