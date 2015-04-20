require "support/sequel_test_support"

RSpec.shared_context "sequel persistence setup" do
  include SequelMapper::SequelTestSupport

  before { truncate_tables }

  let(:datastore) {
    db_connection.tap { |db|
      # The query_counter will let us make assertions about how efficiently
      # the database is being used
      db.loggers << query_counter
    }
  }

  let(:query_counter) {
    SequelMapper::SequelTestSupport::QueryCounter.new
  }
end
