# frozen_string_literal: true

require "test_helper"
require "spark/component/attr"

module Spark
  module Component
    class AttrHashTest < Minitest::Test
      parallelize_me!

      def test_html_attrbute_format_on_to_s
        hash = Attr.new
        hash.add foo: :bar

        assert_equal %(foo="bar"), hash.to_s
      end

      def test_prefix_prepends_keys_on_to_s
        data = Attr.new(prefix: :data)
        data.add foo_bar: :baz

        assert_equal %(data-foo-bar="baz"), data.to_s

        aria = Attr.new(prefix: :aria)
        aria.add foo_bar: :baz

        assert_equal %(aria-foo-bar="baz"), aria.to_s
      end

      def test_dasherize_keys
        hash = Attr.new

        hash.add(foo_bar: :baz)

        assert_equal "foo-bar", hash.keys.first
      end

      def test_does_not_allow_nil_attributes
        hash = Attr.new
        hash.add({ id: "hi", class: [], data: { foo: nil }, aria: nil, string: '' })

        assert_equal({:id=>"hi"}, hash)
      end
    end
  end
end
