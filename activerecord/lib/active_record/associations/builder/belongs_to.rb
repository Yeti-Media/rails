
module ActiveRecord::Associations::Builder
  class BelongsTo < SingularAssociation #:nodoc:
    def macro
      :belongs_to
    end

    def valid_options
      super + [:foreign_type, :polymorphic, :touch]
    end

    def constructable?
      !options[:polymorphic]
    end

    def build
      reflection = super
      add_counter_cache_callbacks(reflection) if options[:counter_cache]
      add_touch_callbacks(reflection)         if options[:touch]
      configure_dependency
      reflection
    end

    private

      def add_counter_cache_callbacks(reflection)
        cache_column = reflection.counter_cache_column
        name         = self.name

        method_name = "belongs_to_counter_cache_after_create_for_#{name}"
        mixin.redefine_method(method_name) do
          record = send(name)
          record.class.increment_counter(cache_column, record.id) unless record.nil?
        end
        model.after_create(method_name)

        method_name = "belongs_to_counter_cache_before_destroy_for_#{name}"
        mixin.redefine_method(method_name) do
          unless marked_for_destruction?
            record = send(name)
            record.class.decrement_counter(cache_column, record.id) unless record.nil?
          end
        end
        model.before_destroy(method_name)

        model.send(:module_eval,
          "#{reflection.class_name}.send(:attr_readonly,\"#{cache_column}\".intern) if defined?(#{reflection.class_name}) && #{reflection.class_name}.respond_to?(:attr_readonly)", __FILE__, __LINE__
        )
      end

      def add_touch_callbacks(reflection)
        name        = self.name
        method_name = "belongs_to_touch_after_save_or_destroy_for_#{name}"
        touch       = options[:touch]

        mixin.redefine_method(method_name) do
          record = send(name)

          unless record.nil?
            if touch == true
              record.touch
            else
              record.touch(touch)
            end
          end
        end

        model.after_save(method_name)
        model.after_touch(method_name)
        model.after_destroy(method_name)
      end

      def configure_dependency
        if dependent = options[:dependent]
          check_valid_dependent! dependent, [:destroy, :delete]

          method_name = "belongs_to_dependent_#{dependent}_for_#{name}"
          model.send(:class_eval, <<-eoruby, __FILE__, __LINE__ + 1)
            def #{method_name}
              association = #{name}
              association.#{dependent} if association
            end
          eoruby
          model.after_destroy method_name
        end
      end
  end
end
