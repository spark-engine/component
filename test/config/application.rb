# frozen_string_literal: true

require File.expand_path("boot", __dir__)

require "active_model/railtie"
require "action_controller/railtie"
require "action_view/railtie"
require "action_view/component/base"
require "sprockets/railtie"
require "slim"
require "pry-byebug"

module Dummy
  class Application < Rails::Application
  end
end

Dummy::Application.config.secret_key_base = "foo"
