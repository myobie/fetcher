require 'json'
require 'nokogiri'
require 'rest-client'

class InstagramService
  class MissingClientId < StandardError; end
  class MissingClientSecret < StandardError; end
  class MissingAccessToken < StandardError; end
  class MissingRedirectURL < StandardError; end
  class CannotFindUserId < StandardError; end

  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def self.client_id
    ENV["INSTAGRAM_CLIENT_ID"] || raise(MissingClientId)
  end

  def self.client_secret
    ENV["INSTAGRAM_CLIENT_SECRET"] || raise(MissingClientSecret)
  end

  def self.redirect_url
    ENV["INSTAGRAM_REDIRECT_URL"] || raise(MissingRedirectURL)
  end

  def self.access_token
    ENV["INSTAGRAM_ACCESS_TOKEN"] || raise(MissingAccessToken)
  end

  def self.url_for(path, api: true, version: true)
    if path =~ /^http:/
      path
    else
      api_text = if api then "api." else "" end
      version_text = if version then "/v1" else "" end
      "https://#{api_text}instagram.com#{version_text}#{path}"
    end
  end

  def url_for(*args)
    self.class.url_for(*args)
  end

  def initialize(user:)
    @user = user
  end

  def api_params(**params)
    {
      client_id: self.class.client_id,
      access_token: self.class.access_token
    }.merge(params)
  end

  def get(path, **params, &blk)
    RestClient.get path, accept: :json, params: api_params(**params), &blk
  end

  def data(json)
    json = JSON.parse json

    if json["meta"] && json["meta"]["code"] == 200
      json["data"]
    end
  end

  def search_url
    url_for "/users/search"
  end

  def username_search_json
    get search_url, q: @user, count: 1
  end

  def user_id
    return @user_id if defined?(@user_id)

    first_user = data(username_search_json).first

    if first_user
      @user_id = first_user["id"]
    else
      raise CannotFindUserId
    end
  end

  def profile_url
    url_for "/users/#{user_id}"
  end

  def profile_json
    get profile_url
  end

  def profile
    @profile ||= data profile_json
  end

  def followers
    if profile["counts"]
      profile["counts"]["followed_by"]
    else
      0
    end
  end

  def following
    if profile["counts"]
      profile["counts"]["follows"]
    else
      0
    end
  end

  def photos_count
    if profile["counts"]
      profile["counts"]["media"]
    else
      0
    end
  end

  def profile_html_url
    url_for "/#{@user}", api: false, version: false
  end

  def recent_photos_url
    url_for "/users/#{user_id}/media/recent"
  end

  def recent_photos_json
    get(recent_photos_url, count: 100)
  end

  def recent_photos
    data(recent_photos_json).map do |image|
      {
        html_url: image["link"],
        image: image["images"]["standard_resolution"],
        tags: image["tags"] || []
      }
    end
  end

  def to_h
    {
      profile_url: profile_html_url,
      user_id: user_id,
      followers: followers,
      following: following,
      photos: photos_count,
      latest: recent_photos,
    }
  end
end
