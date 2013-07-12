require 'json'
require 'nokogiri'
require 'rest-client'

class GithubService
  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def self.url_for(path)
    if path =~ /^http:/
      path
    else
      "https://api.github.com#{path}"
    end
  end

  def url_for(path)
    self.class.url_for(path)
  end

  def initialize(user: user)
    @user = user
  end

  def profile_url
    url_for "/users/#{@user}"
  end

  def profile_json
    RestClient.get profile_url
  end

  def profile
    @profile ||= JSON.parse profile_json
  end

  def starred_url
    url_for "/users/#{@user}/starred"
  end

  def starred_json_size
    response = RestClient.get starred_url

    result = JSON.parse(response).size

    link = response.headers[:link]
    possible_last_link = if link then link.split(",")[1] end

    if possible_last_link && possible_last_link =~ /last/
      last_page_url, rel = possible_last_link.split(";").map(&:strip)
      last_page_url.gsub!(/^</, '')
      last_page_url.gsub!(/>$/, '')
      page = last_page_url.split("=").last.to_i

      result *= page - 1

      last_page_response = RestClient.get last_page_url
      result += JSON.parse(last_page_response).size
    end

    result
  end

  def profile_html_url
    "https://github.com/#{@user}"
  end

  def profile_html_content
    @profile_html_content ||= RestClient.get profile_html_url
  end

  def profile_html_document
    Nokogiri::HTML(profile_html_content)
  end

  def current_streak
    profile_html_document.at("div.contrib-streak-current span.num").text
  end

  def public_repos
    profile["public_repos"]
  end

  def followers
    profile["followers"]
  end

  def url
    profile["html_url"]
  end

  def to_h
    {
      profile_url: url,
      public_repos: public_repos,
      followers: followers,
      starred: starred_json_size,
      current_streak: current_streak,
    }
  end
end
