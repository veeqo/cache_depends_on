$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'active_record'
require 'cache_depends_on'

RSpec.configure do |config|
  config.before(:all) do
    ActiveRecord::Base.establish_connection(:adapter => 'sqlite3', :database => ':memory:')
    require_relative './support/database_schema'
  end
end
