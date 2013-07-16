require 'json'
require 'nokogiri'
require 'rest-client'
require 'time'
require 'uri'
require 'openssl'
require 'base64'

class TumblrService
  class MissingApiKey < StandardError; end
  class MissingOauthCredentials < StandardError; end

  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def self.consumer_key
    ENV["TUMBLR_CONSUMER_KEY"] || raise(MissingOauthCredentials, "consumer_key")
  end

  def self.consumer_secret
    ENV["TUMBLR_CONSUMER_SECRET"] || raise(MissingOauthCredentials, "consumer_secret")
  end

  def self.token
    ENV["TUMBLR_TOKEN"] || raise(MissingOauthCredentials, "token")
  end

  def self.token_secret
    ENV["TUMBLR_TOKEN_SECRET"] || raise(MissingOauthCredentials, "token_secret")
  end

  def self.api_key
    ENV["TUMBLR_API_KEY"] || raise(MissingApiKey)
  end

  def self.oauth_header(verb, url, **params)
    params[:oauth_consumer_key] = consumer_key
    params[:oauth_nonce] = Base64.encode64(OpenSSL::Random.random_bytes(32)).gsub(/\W/, '')
    params[:oauth_signature_method] = 'HMAC-SHA1'
    params[:oauth_timestamp] = Time.now.to_i
    params[:oauth_token] = token
    params[:oauth_version] = '1.0'
    params[:oauth_signature] = oauth_sig(verb, url, **params)

    header = params.map do |key, value|
      if key.to_s.include?('oauth')
        "#{key.to_s}=#{value}"
      end
    end.compact

    "OAuth #{header.join(", ")}".tap { |h| puts h }
  end

  def self.oauth_sig(verb, url, **params)
    parts = [verb.to_s.upcase, URI.encode(url.to_s, /[^a-z0-9\-\.\_\~]/i)]

    params = Hash[params.sort_by{ |key, value| key.to_s}]

    encoded = params.map do |key, value|
      "#{key.to_s}=#{URI.encode(value.to_s, /[^a-z0-9\-\.\_\~]/i)}"
    end

    parts << URI.encode(encoded.join('&'), /[^a-z0-9\-\.\_\~]/i)
    signature_base = parts.join('&')
    secret = "#{consumer_secret}&#{token_secret}"
    Base64.encode64(OpenSSL::HMAC.digest(
      OpenSSL::Digest::SHA1.new, secret, signature_base)
    ).chomp.gsub(/\n/, '')
  end

  def self.url_for(path, api: true, version: true)
    if path =~ /^http:/
      path
    else
      api_text = if api then "api." else "" end
      version_text = if version then "/v2" else "" end
      "https://#{api_text}tumblr.com#{version_text}#{path}"
    end
  end

  def url_for(*args)
    self.class.url_for(*args)
  end

  def initialize(user: user)
    @user = user
  end

  def api_params(**params)
    {
      api_key: self.class.api_key
    }.merge(params)
  end

  def get(path, **params)
    params = api_params(**params)
    RestClient.get(path, accept: :json,
                         params: params,
                         headers: {
                           "Authorization" => self.class.oauth_header(:get, path, **params),
                           "Content-Type" => 'application/x-www-form-urlencoded'
                         }) do |res, req, result, &blk|
                           puts req.inspect
                           puts res.inspect
                           puts result.inspect
                           res
                         end
  end

  def data(json)
    json = JSON.parse json

    if json["meta"] && json["meta"]["status"] == 200
      json["response"]
    end
  end

  def blog_info_url
    url_for "/blog/#{@user}.tumblr.com/info"
  end

  def blog_info_json
    @blog_info_json ||= get blog_info_url
  end

  def blog_info
    @blog_info ||= data(blog_info_json)["blog"]
  end

  def posts_count
    blog_info["posts"]
  end

  def html_url
    blog_info["url"]
  end

  def likes_count
    blog_info["likes"]
  end

  def followers_url
    url_for "/blog/#{@user}.tumblr.com/followers"
  end

  def followers_json
    get followers_url, limit: 1
  end

  def followers_count
    data(followers_json)["total_users"]
  end

  def to_h
    {
      url: html_url,
      posts_count: posts_count,
      likes_count: likes_count,
      followers_count: followers_count
    }
  end
end
