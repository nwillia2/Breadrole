class CreateBreadroleTables < ActiveRecord::Migration
  def self.up
    create_table :breadrole_securityroles do |t|
      t.string :rolename
      t.boolean :active, :default => true, :null => false
      t.integer :roletype

      t.timestamps
    end
    
    create_table :breadrole_controllers do |t|
      t.string :name
      t.boolean :active, :default => true, :null => false

      t.timestamps
    end
    
    create_table :breadrole_actions do |t|
      t.string :name
      t.boolean :active, :default => true, :null => false

      t.timestamps
    end
    
    create_table :breadrole_securityroles_controllers do |t|
      t.integer :breadrole_securityrole_id
      t.integer :breadrole_controller_id

      t.timestamps
    end
    
    add_index :breadrole_securityroles_controllers, :breadrole_securityrole_id
    add_index :breadrole_securityroles_controllers, :breadrole_controller_id
    
    create_table :breadrole_controllers_actions do |t|
      t.integer :breadrole_controller_id
      t.integer :breadrole_action_id      

      t.timestamps
    end
    
    add_index :breadrole_controllers_actions, :breadrole_controller_id    
    add_index :breadrole_controllers_actions, :breadrole_action_id
  end

  def self.down
    drop_table :securityroles
  end
end