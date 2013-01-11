module Breadrole
  class Engine < Rails::Engine

    config.autoload_paths << File.expand_path("../lib/breadrole/", __FILE__)

    initializer "breadrole.load_app_instance_data" do |app|
      Breadrole.setup do |config|
        config.app_root = app.root
      end
    end

    initializer "breadrole.load_static_assets" do |app|
      app.middleware.use ::ActionDispatch::Static, "#{root}/public"
    end

  end
end