require 'rack/contrib/jsonp'
require 'redis'

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

def cache
  host = request.host
  path = request.path_info
  key = [:v1, :request, host, path, :json].join(":")
  Cache.fetch(key) { yield }
end

$redis = Redis.connect url: ENV["REDIS_URL"]

class CachedValue
  attr_reader :value, :expiry

  def initialize(value = nil, expiry = Time.now.utc)
    @value = value
    @expiry = case expiry
              when Time then expiry
              when String then Time.parse(expiry)
              end
    @expiry ||= Time.now.utc
  end

  def expired?
    expiry < Time.now.utc
  end

  def refresh?
    value.nil? || value.empty? || expired?
  end
end

module Cache
  module_function

  def write(key, content)
    an_hour = Time.now.utc + 3_600
    $redis.hmset key, "content", content, "expiry", an_hour
  end

  def remove(key)
    $redis.del key
    true
  end

  def read(key)
    possible_hash = $redis.hgetall key
    if possible_hash.nil?
      CachedValue.new
    else
      CachedValue.new possible_hash["content"], possible_hash["expiry"]
    end
  end

  def fetch(key)
    cached_value = read key

    if cached_value.refresh?
      new_value = begin
        yield
      rescue StandardError
        # notify someone
        nil
      end

      if new_value.nil?
        cached_value.value
      else
        write key, new_value
        puts "}}} writing to cache for: #{key}"
        new_value
      end
    else
      puts "}}} reading from cache for: #{key}"
      cached_value.value
    end
  end
end
