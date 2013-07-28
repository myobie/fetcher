require 'json'
require 'nokogiri'
require 'rest-client'

class DribbbleService
  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def self.url_for(path, api: true, version: true)
    if path =~ /^http:/
      path
    else
      api_text = if api then "api." else "" end
      "http://#{api_text}dribbble.com#{path}"
    end
  end

  def url_for(*args)
    self.class.url_for(*args)
  end

  def initialize(user: user)
    @user = user
  end

  def get(path, **params)
    args = { accept: :json, params: params }
    RestClient.get path, args
  end

  def player_info_url
    url_for "/players/#{@user}"
  end

  def player_info_json
    get player_info_url
  end

  def player_info
    @player_info ||= JSON.parse player_info_json
  end

  def profile_url
    player_info["url"]
  end

  def profile_html_content
    RestClient.get profile_url
  end

  def profile_html_document
    Nokogiri::HTML(profile_html_content)
  end

  def projects
    profile_html_document.at(".secondary h3.tab a span.meta").text.to_i
  end

  def shots_count
    player_info["shots_count"]
  end

  def likes_count
    player_info["likes_count"]
  end

  def shots_url
    url_for "/players/#{@user}/shots"
  end

  def shots_json
    get shots_url, per_page: 4
  end

  def projects_html_url
    "#{profile_url}/projects"
  end

  def latest_shots
    @shots ||= JSON.parse(shots_json)["shots"].map do |shot|
      {
        url: shot["short_url"],
        title: shot["title"],
        image: {
          url: shot["image_url"],
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
