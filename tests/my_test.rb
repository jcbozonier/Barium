require "./src/barium_server"
require "test/unit"
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class HelloWorldTest < Test::Unit::TestCase
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  def test_it_says_hai
    get '/'
    #assert last_response.ok?, "should at least get no errors"
    assert_equal 'hai', last_response.body, "The body of the response should be hai"
  end
end