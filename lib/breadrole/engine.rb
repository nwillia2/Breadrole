module Breadrole
  class Engine < Rails::Engine

    config.after_initialize do |app|
      Breadrole.setup do |config|
        config.app_root = app.root
      end
      
      app.middleware.use ::ActionDispatch::Static, "#{root}/public"
    end

  end
end