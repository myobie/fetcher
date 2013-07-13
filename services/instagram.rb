require 'json'
require 'nokogiri'
require 'rest-client'

class InstagramService
  class MissingClientId < StandardError; end
  class CannotFindUserId < StandardError; end

  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def self.client_id
    ENV["INSTAGRAM_CLIENT_ID"] || raise(MissingClientId)
  end

  def self.url_for(path, api: true)
    if path =~ /^http:/
      path
    else
      api_text = if api then "api." else "" end
      version_text = if api then "/v1" else "" end
      "https://#{api_text}instagram.com#{version_text}#{path}"
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
      client_id: self.class.client_id
    }.merge(params)
  end

  def get(path, **params, &blk)
    RestClient.get path, accept: :json, params: api_params(params), &blk
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

  def photos_count
    if profile["counts"]
      profile["counts"]["media"]
    else
      0
    end
  end

  def profile_html_url
    url_for "/#{@user}", api: false
  end

  def profile_html_content
    @profile_html_content ||= RestClient.get profile_html_url
  end

  def profile_html_document
    Nokogiri::HTML(profile_html_content)
  end

  def recent_photos
    []
  end

  def to_h
    {
      profile_url: profile_html_url,
      user_id: user_id,
      followers: followers,
      photos: photos_count,
      latest: recent_photos,
    }
  end
end
