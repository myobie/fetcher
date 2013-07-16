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

    header = []
    params.map do |key, value|
      if key.to_s.include?('oauth')
        header << "#{key.to_s}=#{value}"
      end
    end

    "OAuth #{header.join(", ")}"
  end

  def self.oauth_sig(verb, url, **params)
    parts = [verb.to_s.upcase, URI.encode(url.to_s, /[^a-z0-9\-\.\_\~]/i)]

    params = Hash[params.sort_by{ |key, value| key.to_s}]

    encoded = []
    params.map do |key, value|
      encoded << "#{key.to_s}=#{URI.encode(value.to_s, /[^a-z0-9\-\.\_\~]/i)}"
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
      "http://#{api_text}tumblr.com#{version_text}#{path}"
    end
  end

  def url_for(*args)
    self.class.url_for(*args)
  end

  def initialize(user: user)
    @user = user
  end

  def get(path, oauth: false, **params)
    args = { accept: :json, params: params }

    if oauth
      args[:authorization] = self.class.oauth_header(:get, path, **params)
    else
      args[:params][:api_key] = self.class.api_key
    end

    RestClient.get path, args
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

  def likes_url
    url_for "/user/likes"
  end

  def likes_json
    get likes_url, oauth: true, limit: 1
  end

  def likes_count
    data(likes_json)["liked_count"]
  end

  def followers_url
    url_for "/blog/#{@user}.tumblr.com/followers"
  end

  def followers_json
    get followers_url, oauth: true, limit: 1
  end

  def followers_count
    data(followers_json)["total_users"]
  end

  def latest_posts_url
    url_for "/blog/#{@user}.tumblr.com/posts"
  end

  def latest_posts_json
    get latest_posts_url, limit: 3, filter: 'text'
  end

  def latest_posts
    data(latest_posts_json)["posts"]
  end

  def latest
    latest_posts.map do |post|
      puts post.inspect
      TumblrPost.detect(post).to_h
    end
  end

  def to_h
    {
      url: html_url,
      posts_count: posts_count,
      likes_count: likes_count,
      followers_count: followers_count,
      latest: latest
    }
  end
end

class TumblrPost
  def self.detect(params)
    case params["type"]
    when "photo"
      TumblrPhotoPost.new(params)
    when "text", "chat"
      TumblrTextPost.new(params)
    when "link"
      TumblrLinkPost.new(params)
    when "video"
      TumblrVideoPost.new(params)
    else
      new(params)
    end
  end

  attr_accessor :params

  def initialize(params)
    @params = params
  end

  def short_url
    params["short_url"]
  end

  def type
    params["type"]
  end

  def date
    params["date"]
  end

  def to_h
    {
      url: short_url,
      type: type,
      date: date
    }
  end
end

class TumblrLinkPost < TumblrPost
  def title
    params["title"]
  end

  def link_url
    params["url"]
  end

  def description
    params["description"]
  end

  def to_h
    super.merge({
      link_url: link_url,
      description: description,
      title: title
    })
  end
end

class TumblrTextPost < TumblrPost
  def title
    params["title"]
  end

  def body
    params["body"]
  end

  def to_h
    super.merge({
      title: title,
      body: body
    })
  end
end

class TumblrVideoPost < TumblrPost
  def caption
    params["caption"]
  end

  def thumbnail
    {
      url: params["thumbnail_url"],
      width: params["thumbnail_width"],
      height: params["thumbnail_height"]
    }
  end

  def to_h
    super.merge({
      thumbnail: thumbnail,
      caption: caption
    })
  end
end

class TumblrPhotoPost < TumblrPost
  def photos
    params["photos"].map do |photo|
      {
        caption: photo["caption"],
        image: photo["alt_sizes"].first
      }
    end
  end

  def source_url
    params["source_url"]
  end

  def mulitple?
    params["photos"].length > 1
  end

  def photo_or_photos
    if mulitple?
      { photos: photos }
    else
      { photo: photos.first }
    end
  end

  def caption
    params["caption"]
  end

  def type
    if mulitple?
      "photoset"
    else
      "photo"
    end
  end

  def to_h
    super.merge(photo_or_photos).merge(description: caption, source_url: source_url)
  end
end
