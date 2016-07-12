require 'json'
require 'nokogiri'
require 'rest-client'

class DribbbleService
  MissingAccessToken = Class.new StandardError

  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def self.access_token
    ENV["DRIBBBLE_CLIENT_ACCESS_TOKEN"] || raise(MissingAccessToken)
  end

  def self.url_for(path, api: true, version: true)
    if path =~ /^http:/
      path
    else
      api_text = if api then "api." else "" end
      path = "/v1#{path}"
      "https://#{api_text}dribbble.com#{path}"
    end
  end

  def api_params(**params)
    params.merge(access_token: self.class.access_token)
  end

  def url_for(*args)
    self.class.url_for(*args)
  end

  def initialize(user:)
    @user = user
  end

  def get(path, **params)
    RestClient.get path, accept: :json, params: api_params(**params)
  end

  def player_info_url
    url_for "/users/#{@user}"
  end

  def player_info_json
    get player_info_url
  end

  def player_info
    @player_info ||= JSON.parse player_info_json
  end

  def profile_url
    player_info["html_url"]
  end

  def profile_html_content
    RestClient.get profile_url
  end

  def profile_html_document
    Nokogiri::HTML(profile_html_content)
  end

  def projects
    player_info["projects_count"]
  end

  def shots_count
    player_info["shots_count"]
  end

  def likes_count
    player_info["likes_count"]
  end

  def shots_url
    url_for "/users/#{@user}/shots"
  end

  def shots_json
    get shots_url, per_page: 20
  end

  def projects_html_url
    "#{profile_url}/projects"
  end

  def latest_shots
    @shots ||= JSON.parse(shots_json).map do |shot|
      images = shot.fetch("images")
      image_url = images.fetch("hidpi") { images.fetch("normal") }
      {
        url: shot["html_url"],
        title: shot["title"],
        image: {
          url: image_url,
          width: shot["width"],
          height: shot["height"]
        }
      }
    end
  end

  def to_h
    {
      profile_url: profile_url,
      projects_url: projects_html_url,
      shots: shots_count,
      likes: likes_count,
      projects: projects,
      latest: latest_shots
    }
  end
end
