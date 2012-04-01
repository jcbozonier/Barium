require "sinatra/base"

class BariumServer < Sinatra::Base
  get "/my_tracking_script" do
    "hai"
  end
end