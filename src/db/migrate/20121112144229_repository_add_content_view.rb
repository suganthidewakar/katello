class RepositoryAddContentView < ActiveRecord::Migration
  def self.up
    add_column :repositories, :content_view_version_id, :integer, :null=>true
    add_index :repositories, :content_view_version_id

    User.current = User.hidden.first
    KTEnvironment.all.each do |env|
     view = ContentView.create!(:name=>"Default View for #{env.name}",
                         :organization=>env.organization, :default=>true)
     env.default_content_view = view
     env.save!
     version = ContentViewVersion.create!(:version=>1, :content_view=>view)
     env.repositories.each do |repo|
       repo.content_view_version = version
       repo.save!
     end
    end

    change_column :repositories, :content_view_version_id, :integer, :null => false
  end

  def self.down
    KTEnvironment.all.each do |env|
      env.default_content_view.destroy!
    end
    remove_column :repositories, :content_view_version_id
  end
end
