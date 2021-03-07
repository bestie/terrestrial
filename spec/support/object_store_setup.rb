require "terrestrial"
require "terrestrial/relational_store"
require "terrestrial/relation_mapping"
require "terrestrial/lazy_collection"
require "terrestrial/collection_mutability_proxy"
require "terrestrial/lazy_object_proxy"
require "terrestrial/dataset"
require "terrestrial/query_order"
require "terrestrial/one_to_many_association"
require "terrestrial/many_to_one_association"
require "terrestrial/many_to_many_association"
require "terrestrial/subset_queries_proxy"
require "support/object_graph_setup"

RSpec.shared_context "object store setup" do
  include_context "object graph setup"

  let(:object_store) {
    Terrestrial.object_store(mappings: mappings, datastore: datastore)
  }

  let(:user_store) { object_store[:users] }

  let(:mappings) {
    Terrestrial.config(datastore)
      .setup_mapping(:users) { |users|
        users.has_many(:posts, foreign_key: :author_id)
      }
      .setup_mapping(:posts) { |posts|
        posts.fields([:id, :subject, :body, :created_at])
        posts.has_many(:comments)
        posts.has_many_through(:categories)
      }
      .setup_mapping(:comments) { |comments|
        comments.fields([:id, :body])
        comments.belongs_to(:commenter, mapping_name: :users)
      }
      .setup_mapping(:categories) { |categories|
        categories.has_many_through(:posts)
      }
  }
end
