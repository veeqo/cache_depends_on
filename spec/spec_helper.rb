$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record'
require 'cache_depends_on'
require 'database_cleaner'

DatabaseCleaner.strategy = :truncation

RSpec.configure do |config|
  config.before(:suite) do
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
    ActiveRecord::Migration.verbose = false
    require_relative './support/database_schema'
  end

  config.append_after(:each) do
    DatabaseCleaner.clean
  end
end
