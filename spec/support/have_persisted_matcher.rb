RSpec::Matchers.define :have_persisted do |relation_name, data|
  match do |datastore|
    datastore[relation_name].find { |record|
      if data.respond_to?(:===)
        data === record
      else
        data == record
      end
    }
  end

  failure_message do |datastore|
    "expected #{datastore[relation_name]} to have persisted #{data.inspect} in #{relation_name}"
  end

  failure_message_when_negated do |datastore|
    failure_message.gsub("to have", "not to have")
  end
end
