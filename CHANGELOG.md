# v1.1.2 - 2020-01-14
- Fix: Added render checking to component to prevent executing `render_self` more than once. 

# v1.1.1 - 2020-01-14
- Fix: When a nested element is referenced it will trigger the parent to yield
    its block, ensuring that the nested element reference will be instantiated
    if it is used in the parent's block.
- Fix: Elements now have a `blank?` method and `present?` returns `!blank?`. It
    is important to remember, `blank?` and `present?` return false if an element
    yields nothing. To check for the existence of an element instance, use `nil?`.
- New: Elements now have access to their own name with the `_name` method.

# v1.1.0 - 2020-01-10

- New: Class method `attribute_default_group` makes it easy to set defaults for multiple attributes based on a single component argument. It's great for theming, where setting `theme: :notice` can set attributes for color, layout, etc.
- New: Class methods `tag_attribute`, `data_attribute`, and `aria_attribute` make it easy to sync component arguments to tag_attrs object.

# v1.0.1 - 2020-01-08

- Fix: added `deep_compact` to Attr and TagAttr to ensure that `nil` or `empty?` objects are ignored.

# v1.0.0 - 2019-12-18

- Initial release
