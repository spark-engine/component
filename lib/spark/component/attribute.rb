# frozen_string_literal: true

require "spark/component/tag_attr"

# Allows components to easily manage their attributes
#
#  # Example component usage:
#
#    class SomeClass
#      include Spark::Component::Attribute
#
#      # Set a :label attribute, and a :size attribute with default value :large
#      attribute :label, { size: :large }
#
#      def inialize(attributes = nil)
#        initialize_attributes(attributes)
#      end
#    end
#
#  # When initialized like:
#
#    some_instance = SomeClass.new(label: "Test")
#
#  The Class's instance will now have access to
#
#    @label => "Test"
#    @size  => :large
#
#  And will define access methods:
#
#    some_instance.attribute_label
#    some_instance.attribute_size
#
#  Attributes can also be accessed with a helper method
#
#    some_instance.attribute(:label)
#    some_instance.attribute(:size)
#
#  Extending a class will extend its attributes and their defaults.
#
#  This supports a common set of base attributes such as id, class, data, aria, and html.
#  The html attribute is meant to allow for passing along unaccounted for tag attributes.
#
module Spark
  module Component
    BASE_ATTRIBUTES = %i[id class data aria html].freeze

    module Attribute
      # All components and elements will support these attributes

      def self.included(base)
        base.extend(ClassMethods)
      end

      def initialize(*attrs)
        initialize_attributes(*attrs)
      end

      # Assign instance variables for attributes defined by the class
      def initialize_attributes(attrs = nil)
        attrs ||= {}

        # Filter out attributes which aren't defined by class method
        attrs.select! { |key, _value| self.class.attributes.keys.include?(key) }

        initialize_attribute_default_groups(attrs)

        self.class.attributes.each do |name, default|
          default = (!default.nil? ? default : nil)
          value = attrs[name].nil? ? default : attrs[name]

          if set?(value)
            instance_variable_set(:"@#{name}", value)
          end
        end
      end

      # Takes attributes passed to a component or element and assigns values to other
      # attributes as defined in their group.
      #
      # For example, with an attribute group:
      #   theme: {
      #     notice: { icon: "message", color: "blue" }
      #     error: { icon: "error", color: "red" }
      #   }
      #
      # If the attributes include `theme: :notice`, the icon and color attributes
      # would default to "message" and "blue", but could be overriden if the user
      # set values for them.
      #
      def initialize_attribute_default_groups(attrs)
        self.class.attribute_default_groups.each do |group, group_options|
          # Determine what group name is set for this attribute.
          # In the above example the group would be `theme` and the name
          # would be the value passed for `theme`, or its default value.
          #
          # So `name` might be `:notice`.
          name = attrs[group] || self.class.attributes[group]

          # Normalize name for hash lookup. to_s.to_sym converts booleans as well.
          name = name.to_s.to_sym unless name.nil?

          # Get defaults to set from group name
          # In the above example, if the name were `notice` this would be the hash
          # `{ icon: "message", color: "blue" }`
          defaults = group_options[name]

          next unless defaults
          unless defaults.is_a?(Hash)
            raise("In argument group `:#{name}`, value `#{defaults}` must be a hash.")
          end

          defaults.each do |key, value|
            if attrs[key].nil?
              attrs[key] = value
              instance_variable_set(:"@#{key}", value)
            end
          end
        end
      end

      def attribute(name)
        attributes[name]
      end

      def attributes
        attr_hash(*self.class.attributes.keys)
      end

      # Accepts an array of instance variables and returns
      # a hash of variables with their values, if they are set.
      #
      # Example:
      #   @a = 1
      #   @b = nil
      #
      #   attr_hash(:a, :b, :c) => { a: 1 }
      #
      # Example use case:
      #
      # <div data="<%= attr_hash(:remote, :method)) %>">
      #
      def attr_hash(*args)
        args.each_with_object({}) do |name, obj|
          val = instance_variable_get(:"@#{name}")
          next if val.nil?

          # Stringify true values to ensure the value is set in tag attributes
          # This helps tags write `data-foo="true"` instead of `data-foo`
          obj[name] = val == true ? val.to_s : val
        end
      end

      # Initialize tag attributes
      #
      # If a component or element defines tag_attributes, aria_attributes, or data_attributes
      # Automatically assign add arguments to tag_attrs
      def tag_attrs
        return @tag_attrs if @tag_attrs

        @tag_attrs = TagAttr.new.add(attr_hash(*self.class.tag_attributes))
        @tag_attrs.add(aria: attr_hash(*self.class.aria_attributes))
        @tag_attrs.add(data: attr_hash(*self.class.data_attributes))
        @tag_attrs
      end

      # Easy reference a tag's classname
      def classname
        tag_attrs.classname
      end

      # Easy reference a tag's data attributes
      def data
        tag_attrs.data
      end

      # Easy reference a tag's aria attributes
      def aria
        tag_attrs.aria
      end

      private

      # Help filter out attributes with blank values.
      # Not using `blank?` to avoid Rails requirement
      # and because `false` is a valid value.
      def set?(value)
        !(value.nil? || value.respond_to?(:empty?) && value.empty?)
      end

      module ClassMethods
        def attributes
          # Set attributes default to a hash using keys defined by BASE_ATTRIBUTES
          @attributes ||= Spark::Component::BASE_ATTRIBUTES.each_with_object({}) do |val, obj|
            obj[val] = nil
          end
        end

        # Sets attributes, accepts an array of keys, pass a hash to set default values
        #
        # Examples:
        #   - attribute(:foo, :bar, :baz)               => { foo: nil, bar: nil, baz: nil }
        #   - attribute(:foo, :bar, { baz: true })      => { foo: nil, bar: nil, baz: true }
        #   - attribute(foo: true, bar: true, baz: nil) => { foo: true, bar: true, baz: nil }
        #
        def attribute(*args)
          args.each do |arg|
            if arg.is_a?(::Hash)
              arg.each do |key, value|
                set_attribute(key.to_sym, default: value)
              end
            else
              set_attribute(arg.to_sym)
            end
          end
        end

        # A namespaced passthrough for validating attributes
        #
        # Option: `choices` - easily validate against an array
        #   Essentially a simplification of `inclusion` for attributes.
        #
        # Examples:
        #   - validates_attr(:size, choices: %i[small medium large])
        #   - validates_attr(:size, choices: SIZES, allow_blank: true)
        #
        def validates_attr(name, options = {})
          name = :"attribute_#{name}"

          if (choices = options.delete(:choices))
            supported_choices = choices.map do |c|
              c.is_a?(String) ? c.to_sym : c.to_s
            end.concat(choices)

            choices = choices.map(&:inspect).to_sentence(last_word_connector: ", or ")
            message = "\"%<value>s\" is not valid. Options include: #{choices}."

            options.merge!(inclusion: { in: supported_choices, message: message })
          end

          validates(name, options)
        end

        # Store attributes to be added to tag_attrs
        def tag_attributes
          @tag_attributes ||= BASE_ATTRIBUTES.dup
        end

        # Store attributes to be added to tag_attrs aria
        def aria_attributes
          @aria_attributes ||= []
        end

        # Store attributes to be added to tag_attrs data
        def data_attributes
          @data_attributes ||= []
        end

        # Add attribute(s) and automatically add to tag_attr
        def tag_attribute(*args)
          attr_object = hash_from_args(*args)

          if (aria_object = attr_object.delete(:aria))
            attribute(aria_object)
            aria_attributes.concat(aria_object.keys)
          end

          if (data_object = attr_object.delete(:data))
            attribute(data_object)
            data_attributes.concat(data_object.keys)
          end

          attribute(attr_object)
          tag_attributes.concat(attr_object.keys)
        end

        # Add attribute(s) and automatically add to tag_attr's aria hash
        def aria_attribute(*args)
          tag_attribute(aria: hash_from_args(*args))
        end

        # Add attribute(s) and automatically add to tag_attr's data hash
        def data_attribute(*args)
          tag_attribute(data: hash_from_args(*args))
        end

        def attribute_default_group(object)
          attribute_default_groups.merge!(object)
        end

        def attribute_default_groups
          @attribute_default_groups ||= {}
        end

        private

        # Store attributes and define methods for validation
        def set_attribute(name, default: nil)
          attributes[name] = default

          # Define a method to access attribute to support validation
          # Namespace attribute methods to prevent collision with methods or elements
          define_method(:"attribute_#{name}") do
            instance_variable_get(:"@#{name}")
          end
        end

        # Convert mixed arguments to a hash
        # Example: (:a, :b, c: true) => { a: nil, b: nil, c: true }
        def hash_from_args(*args)
          args.each_with_object({}) do |arg, obj|
            arg.is_a?(Hash) ? obj.merge!(arg) : obj[arg] = nil
          end
        end
      end
    end
  end
end
