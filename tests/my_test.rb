require "./src/barium_server"
require "test/unit"
require 'rack/test'

ENV['RACK_ENV'] = 'test'

class HelloWorldTest < Test::Unit::TestCase
  def app
    Sinatra::Application
  end

  def test_it_does_not_set_a_new_tracking_cookie_when_the_browser_already_has_one
    session = Rack::MockSession.new(Sinatra::Application)

    session.cookie_jar["barium_trace"] = "SOME BULLSHIT"

    browser = Rack::Test::Session.new(session)
    browser.get '/'

    assert_equal(session.cookie_jar["barium_trace"], "SOME BULLSHIT", "should not overwrite the preexisting cookie")
  end

  def test_it_sets_a_unique_tracking_cookie_for_each_session
    session = Rack::MockSession.new(Sinatra::Application)
    browser = Rack::Test::Session.new(session)
    browser.get '/'

    first_session_tracking_cookie = browser.last_request.cookies["barium_trace"]

    second_session = Rack::MockSession.new(Sinatra::Application)
    browser = Rack::Test::Session.new(second_session)
    browser.get '/'

    second_session_tracking_cookie = browser.last_request.cookies["barium_trace"]

    assert_not_equal(first_session_tracking_cookie, second_session_tracking_cookie, "should have set a unique tracking id for each session in a cookie.")
  end
end