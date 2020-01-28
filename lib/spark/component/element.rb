# frozen_string_literal: true

require "spark/component/attribute"

module Spark
  module Component
    module Element
      class Error < StandardError; end

      def self.included(base)
        base.extend(Spark::Component::Element::ClassMethods)

        %i[_name _parent _block view_context].each do |name|
          base.define_method(:"#{name}=") { |val| instance_variable_set(:"@#{name}", val) }
          base.define_method(:"#{name}")  { instance_variable_get(:"@#{name}") }
        end
      end

      # Initialize method on components must call super
      def initialize(attrs = nil)
        # Extract core element attributes
        # Ensure that elements have references to their:
        #  - parent: enables elements to interact with their parent component
        #  - block: used in render_self
        #  - view_context, sets the view context for an element (in Rails)
        #
        unless attrs.nil? || attrs.empty?
          @_name        = attrs.delete(:_name)
          @_parent      = attrs.delete(:_parent)
          @_block       = attrs.delete(:_block)
          @view_context = attrs.delete(:_view)
        end

        initialize_elements

        # Call Attributes.initialze
        super
      end

      def render_self
        # Guard with `rendered?` boolean in case render_block returns `nil`
        return @render_self if rendered?

        @render_self = render_block(@view_context, &_block)
        validate! if defined?(ActiveModel::Validations)
        @rendered = true
        @render_self
      end

      def rendered?
        @rendered == true
      end

      def render_block(view, &block)
        block_given? ? view.capture(self, &block) : nil
      end

      def yield
        render_self
      end

      def present?
        !blank?
      end

      def blank?
        self.yield.nil? || self.yield.strip.empty?
      end

      private

      # Create instance variables for each element
      def initialize_elements
        self.class.elements.each do |name, options|
          if (plural_name = options[:multiple])

            # Setting an empty array allows us to enumerate
            # without needing to check for presence first.
            set_element_variable(plural_name, [])
          else
            set_element_variable(name, nil)
          end
        end
      end

      # Simplify accessing namespaced element instance variables
      def set_element_variable(name, value)
        instance_variable_set(:"@element_#{name}", value)
      end

      # Simplify accessing namespaced element instance variables
      def get_element_variable(name)
        instance_variable_get(:"@element_#{name}")
      end

      # Override the default value for an element's attribute(s)
      def set_element_attribute_default(element, attrs = {})
        element_attribute_default[element] ||= {}
        element_attribute_default[element].merge!(attrs)
      end

      def element_attribute_default
        @element_attribute_default ||= {}
      end

      # Merge user defined attributes with the overriden attributes of an element
      def merge_element_attribute_default(name, attributes)
        attrs = element_attribute_default[name]
        attributes = attrs.merge(attributes || {}) unless attrs.nil? || attrs.empty?
        attributes
      end

      module ClassMethods
        def inherited(child)
          child.elements.replace(elements)
          child.attributes.replace(attributes)
          child.tag_attributes.replace(tag_attributes)
          child.data_attributes.replace(data_attributes)
          child.aria_attributes.replace(aria_attributes)
          child.attribute_default_groups.replace(attribute_default_groups)
        end

        def elements
          @elements ||= {}
        end

        # Class method for adding elements
        #
        # Options:
        #
        #   name: Symbol
        #
        #     Create a method for interacting with an element
        #     This name cannot be the same as another instance method
        #
        #   multiple: Boolean (default: false)
        #
        #     Defining `multiple: true` causes elements to be injected
        #     into an array. A pluralized method is created to access
        #     each element instance.
        #
        #     For example, `element(:item, multiple: true)` will create
        #     an `:items` method and each time an item is executed, its
        #     instance will be added to items.
        #
        #   component: Class
        #
        #     By default all elements include Element and extend its class methods
        #     Passing a class like `component: Nav::Item` will extend that component
        #     adding Element, Attributes, TagAttr and render methods.
        #
        #   &config: Block
        #
        #     When defining a method, you may pass an optional block to
        #     configure attributes, nested elements, or even define methods.
        #
        def element(name, multiple: false, component: nil, &config)
          plural_name = name.to_s.pluralize.to_sym if multiple
          klass = extend_class(component, &config)
          elements[name] = { multiple: plural_name, class: klass }

          define_element(name: name, plural: plural_name, multiple: multiple, klass: klass)
        end

        # Element method will create a new element instance, or if no
        # attributes or block is passed it will return the instance
        # defined for that element.
        #
        # For example when rendering a component, passing attributes or a
        # block will create a new instance of that element.
        #
        #   # Some view (Slim)
        #   = render(Nav) do |nav|
        #     - nav.item(href: "#url") { "link text" }
        #
        # Then when referencing the element in the component's template it
        # the method will return the instance. Call yield to output an
        # elemnet's block
        #
        #   # Nav template (Slim)
        #   nav
        #     - items.each do |item|
        #       a href=item.href
        #         = item.yield
        #
        def define_element(name:, plural:, multiple:,  klass:)
          define_method_if_able(name) do |attributes = nil, &block|
            # When initializing an element, blocks or arguments are passed.
            # If an element is being referenced without these, it will return its instance
            # This allows the elemnet method to initailize the object and return its instance
            # for template rendering.
            unless block || attributes

              # If an element is called, it will only exist if its parent's block has been exectued
              # Be sure the block has been executed so that sub elements are initialized
              self.yield if is_a?(Spark::Component::Element::Base) && !rendered?

              return get_element_variable(multiple ? plural : name)
            end

            attributes ||= {}
            attributes = merge_element_attribute_default(name, attributes)
            attributes.merge!(_name: name, _parent: self, _block: block, _view: view_context)

            element = klass.new(attributes)

            # If element supports multiple instances, inject instance
            # into array for later enumeration
            if multiple
              get_element_variable(plural) << element
            else
              set_element_variable(name, element)
            end
          end

          return if !multiple || name == plural

          # Define a pluralized method name to access enumerable element instances.
          define_method_if_able(plural) do
            get_element_variable(plural)
          end
        end

        private

        # If an element extends a component, extend that class and include necessary modules
        def extend_class(component, &config)
          base = Class.new(component || Spark::Component::Element::Base, &config)
          define_model_name(base) if defined?(ActiveModel)

          return base unless component

          # Allow element to reference its source component
          base.define_singleton_method(:source_component) { component }

          # Override component when used as an element
          if defined?(Spark::Component::Integration)
            base.include(Spark::Component::Integration::Element)
          end

          base
        end

        # ActiveModel validations require a model_name.
        # This connects new classes to their proper model names.
        def define_model_name(klass)
          klass.define_singleton_method(:model_name) do
            # try the current class, the parent class, or default to Spark::Component
            named_klass = [self.class, superclass, Spark::Component].reject { |k| k == Class }.first
            ActiveModel::Name.new(named_klass)
          end
        end

        # Prevent an element method from overwriting an existing method
        def define_method_if_able(method_name, &block)
          # Protect instance methods which are crucial to components and elements
          methods = [self, Element, Attribute]
          methods << Integration.base_class if defined? Spark::Component::Integration
          methods.map! { |c| c.instance_methods(false) }

          if methods.flatten.include?(method_name.to_sym)
            raise(Element::Error, "Method '#{method_name}' already exists.")
          end

          define_method(method_name, &block)
        end
      end

      # Base class for non-component elements
      class Base
        include ActiveModel::Validations if defined?(ActiveModel)
        include Spark::Component::Attribute
        include Spark::Component::Element
      end
    end
  end
end
