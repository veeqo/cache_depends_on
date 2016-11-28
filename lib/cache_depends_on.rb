require 'cache_depends_on/exceptions'
require 'cache_depends_on/association_cache_dependency_definer'
require 'cache_depends_on/active_record_model_extension'

module CacheDependsOn
  module ClassMethods
    def cache_depends_on(*association_names)
      AssociationCacheDependencyDefiner.new(self).define_cache_dependency_on association_names
    end
  end
end

ActiveRecord::Base.extend CacheDependsOn::ClassMethods
