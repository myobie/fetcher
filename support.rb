require 'rack/contrib/jsonp'

use Rack::JSONP

before do
  content_type :json
end

SERVICES = []

def services(*args)
  SERVICES.concat args
  args.each { |arg| require "./services/#{arg}" }
end

def subdomain(host)
  condition do
    host == request.env['HTTP_HOST'].split('.').first
  end
end
