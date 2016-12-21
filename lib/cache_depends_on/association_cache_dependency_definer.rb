module CacheDependsOn
  class AssociationCacheDependencyDefiner
    def initialize(model_klass)
      @model_klass = model_klass
    end
    attr_reader :model_klass

    def define_cache_dependency_on(association_names)
      find_associations_by_names(association_names).each do |association|
        association.klass.class_eval { include ActiveRecordModelExtension }
        association.klass.invalidates_cache_of << find_inverse_of(association)
      end

      model_klass.class_eval { include ActiveRecordModelExtension }
    end

    private

    def find_associations_by_names(association_names)
      association_names.map do |association_name|
        model_klass.reflect_on_association(association_name).tap do |association|
          raise AssociationNotFound, "association #{association_name} was not found in #{model_klass.name}" if association.nil?
        end
      end
    end

    def find_inverse_of(association)
      find_polymorphic_inverse_of(association) ||
        find_singular_inverse_of(association) ||
        find_plural_inverse_of(association) ||
        raise(ReverseAssociationNotFound, "reverse association of #{model_klass} was not found in #{association.klass}")
    end

    def find_singular_inverse_of(association)
      suggested_singular_reverse_association_name = model_klass.model_name.singular.to_sym
      association.klass.reflect_on_association suggested_singular_reverse_association_name
    end

    def find_plural_inverse_of(association)
      suggested_plural_reverse_association_name = model_klass.model_name.plural.to_sym
      association.klass.reflect_on_association suggested_plural_reverse_association_name
    end

    def find_polymorphic_inverse_of(association)
      association.klass.reflect_on_association association.options[:as]
    end
  end
end
