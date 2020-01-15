# frozen_string_literal: true

require "test_helper"

module Spark
  class ElementIntegrationTest < ActionDispatch::IntegrationTest
    def test_render_without_element
      get "/empty"
      assert_response :success
      assert_equal %(<div></div>), get_html(response.body)
    end

    def test_render_element
      get "/block"
      assert_response :success
      expected = %(<div class="block"><span>content</span></div>)
      assert_equal expected, get_html(response.body, css: ".block")
    end

    def test_element_parent
      component = WithElements.new
      el        = component.simple_block { "hi" }
      assert_equal component, el._parent
    end

    def test_render_element_multiple
      get "/multi"
      assert_response :success
      html = get_html(response.body, css: "ul")
      assert_includes html, %(<li>1</li>)
      assert_includes html, %(<li>2</li>)
      assert_includes html, %(<li>3</li>)
    end

    def test_render_element_with_config
      get "/config"
      assert_response :success
      assert_equal %(<div class="attr">bar</div>), get_html(response.body, css: ".attr")
      assert_equal %(<div class="method">success</div>), get_html(response.body, css: ".method")
      assert_equal %(<div class="content">test</div>), get_html(response.body, css: ".content")
    end

    def test_render_element_with_validation_exception
      exception = assert_raises(ActionView::Template::Error) do
        get "/with_validation_exception"
      end
      assert_includes exception.message, "Validation failed: Attribute foo can't be blank"
    end

    def test_render_element_with_validation_passes
      get "/with_validation"
      assert_response :success
      assert_equal %(<div>works</div>), get_html(response.body)
    end

    def test_render_element_extending_component
      get "/component"
      assert_response :success
      assert_equal %(<div class="el">component-element</div>), get_html(response.body, css: ".el")
    end

    def test_render_element_extending_component_with_elements
      get "/component_with_elements"
      assert_response :success
      assert_equal %(<div class="block">block</div>), get_html(response.body, css: ".block")
      assert_equal %(<strong>hi</strong>), get_html(response.body, css: "strong")
    end

    def test_inherit_tag_attributes_when_extending_class
      klass = Class.new do
        include Component::Attribute
        include Component::Element
        tag_attribute zeep: :zorp
      end

      extended = Class.new(klass)
      instance = extended.new

      assert extended.tag_attributes.include?(:zeep)

      assert_equal :zorp, instance.tag_attrs[:zeep]
    end

    def test_inherit_aria_attributes_when_extending_class
      klass = Class.new do
        include Component::Attribute
        include Component::Element
        aria_attribute meep: :morp
      end

      extended = Class.new(klass)
      instance = extended.new

      assert extended.aria_attributes.include?(:meep)
      assert_equal :morp, instance.aria[:meep]
    end

    def test_inherit_data_attributes_when_extending_class
      klass = Class.new do
        include Component::Attribute
        include Component::Element
        data_attribute bleep: :blorp
      end

      extended = Class.new(klass)
      instance = extended.new

      assert extended.data_attributes.include?(:bleep)
      assert_equal :blorp, instance.data[:bleep]
    end

    def test_render_element_config_extending_component
      get "/component_config"
      assert_response :success

      expected = %(<div class="config">config_default</div>)
      assert_equal expected, get_html(response.body, css: ".config")

      expected = %(<div class="method">success</div>)
      assert_equal expected, get_html(response.body, css: ".method")
    end

    def test_render_element_config_extending_component_validation_exception
      exception = assert_raises(ActionView::Template::Error) do
        get "/component_config_validation_exception"
      end
      assert_includes exception.message, "Validation failed: Attribute a is not a number"
    end

    def test_render_element_config_extending_component_validation_override
      get "/component_config_validation"
      assert_response :success
      assert_equal %(<div class="validated">3</div>), get_html(response.body)
    end

    def test_render_element_extending_component_multiple
      get "/component_multi"
      assert_response :success
      html = get_html(response.body, css: "ul")
      assert_includes html, %(<li><div>1</div></li>)
      assert_includes html, %(<li><div>2</div></li>)
      assert_includes html, %(<li><div>3</div></li>)
    end

    def test_element_yields_if_nested_element_is_called
      get "/component_with_nested_plain_elements"
      assert_response :success
      html = get_html(response.body)
      assert_includes html, %(<div id="child">hello parent</div>)
    end

    def test_element_can_reference_its_own_name
      get "/component_with_element_referencing_name"
      assert_response :success
      html = get_html(response.body)
      assert_includes html, %(<h3>Title</h3>)
    end
  end
end
