Given(/^the domain objects are defined$/) do |code_sample|
  Object.module_eval(code_sample)
end

Given(/^a database connection is established$/) do |code_sample|
  example_eval(code_sample)
end

Given(/^the associations are defined in the configuration$/) do |code_sample|
  example_eval(code_sample)
end

Given(/^a object store is instantiated$/) do |code_sample|
  example_eval(code_sample)
end

Given(/^a conventionally similar database schema for table "(.*?)"$/) do |table_name, schema_table|
  create_table(table_name, parse_schema_table(schema_table))
end

When(/^a new graph of objects are created$/) do |code_sample|
  @objects_to_be_saved_sample = code_sample
end

When(/^the new graph is saved$/) do |save_objects_code|
  example_eval(
    [@objects_to_be_saved_sample, save_objects_code].join("\n")
  )
end

When(/^the following query is executed$/) do |code_sample|
  @query = code_sample
  @result = example_eval(code_sample)
end

Then(/^the persisted user object is returned with lazy associations$/) do |expected_inspection_string|
  expect(normalise_inspection_string(@result.inspect))
    .to eq(normalise_inspection_string(expected_inspection_string))
end

Then(/^the user's posts will be loaded once the association proxy receives an Enumerable message$/) do |expected_inspection_string|
  posts = @result.posts.to_a

  expect(normalise_inspection_string(posts.inspect))
    .to eq(normalise_inspection_string(expected_inspection_string))
end
