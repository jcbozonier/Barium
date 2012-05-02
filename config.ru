require 'sinatra'
require './barium_server'

set :raise_errors, Proc.new { false }
set :show_exceptions, false

run Sinatra::Application