module Acts #:nodoc:
  module Active

    def self.included(base) # :nodoc:
      base.extend(ClassMethods)
    end

    module ClassMethods
      def acts_as_active(options = {})
        # don't let AR call this twice
        unless self.included_modules.include?(InstanceMethods) 
          cattr_accessor :active_attribute
          self.active_attribute = (options[:with] || :active).to_sym
          
          #show only active
          default_scope :conditions => {self.active_attribute => true}

          class << self
            #override the default_scope to inject the active attribute
            alias_method :default_scope_without_active, :default_scope
  
            def default_scope(scope_options)
              scope_options[:conditions] ||= {}
              if scope_options[:conditions].is_a? Hash
                scope_options[:conditions].update(self.active_attribute => true)
              elsif scope_options[:conditions].is_a? Array
                scope_options[:conditions][0] = inject_active_in_condition(scope_options[:conditions][0])
              elsif scope_options[:conditions].is_a? String
                scope_options[:conditions] = inject_active_in_condition(scope_options[:conditions])
              else
                raise "what did you pass as conditions??"
              end
              default_scope_without_active(scope_options)
            end
          end

          #copy the :destroy_without_callbacks
          alias_method :destroy_without_callbacks!, :destroy_without_callbacks
          include InstanceMethods
        end
      end
      
      def find_with_inactive(*args)
        with_exclusive_scope { find(*args) }
      end
      
      def all_with_inactive(*args)
        with_exclusive_scope { all(*args) }
      end
      
      def calculate_with_inactive(*args)
        with_exclusive_scope { calculate(*args) }
      end
      
      def count_with_inactive(*args)
        with_exclusive_scope { count(*args) }
      end

      private
      def inject_active_in_condition(condition)
        "(#{condition}) AND (#{self.active_attribute} = #{quote_value(true)})"
      end
    end

    module InstanceMethods
      def active?
        self[active_attribute]
      end
      
      def activate!
        update_attribute active_attribute, true
      end
      
      def deactivate!
        update_attribute active_attribute, false
      end

      #override the default behavior
      def destroy_without_callbacks
        unless new_record?
          deactivate!
        end
        freeze
      end

      def destroy_with_callbacks!
        return false if callback(:before_destroy) == false
        result = destroy_without_callbacks!
        callback(:after_destroy)
        result
      end

      def destroy!
        transaction { destroy_with_callbacks! } #call the original destroy_with_callbacks
      end
      
      private
      def active_attribute
        self.class.active_attribute
      end

    end
  end
end

