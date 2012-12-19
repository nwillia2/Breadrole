class CreateBreadroleData < ActiveRecord::Migration
  def self.up
    # add some basic data
    # actions
    execute "insert into breadrole_actions (name) (('create'), ('edit'), ('delete'), ('view'), ('list')"
    
    # controllers
    # eager load to get controllers
    Rails.application.eager_load!
    controllers = ApplicationController.descendants
    controllers.each do |controller|
      execute "insert into breadrole_controllers (name) values (('#{controller.to_s.gsub("Controller", "")}')"
      # then for each one, add it's actions
      
    end
  end
  
  def self.down
    
  end
end