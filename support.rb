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

def jsonp(string)
  if params[:callback]
    wrap_with_jsonp_callback params[:callback], string
  else
    string
  end
end

def wrap_with_jsonp_callback(callback, string)
  "#{callback}(#{string})"
end
