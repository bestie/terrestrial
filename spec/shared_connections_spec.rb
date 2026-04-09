# require "spec_helper"
# RSpec.xdescribe "Shared connections" do
#
#   it "shares" do
#     expect(ActiveRecord::Base.connection).to respond_to(:execute)
#     c = ActiveRecord::Base.connection
#     pg =  c.instance_variable_get(:@connection)
#   end
# end
