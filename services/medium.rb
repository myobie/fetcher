require 'json'
require 'nokogiri'
require 'rest-client'

class MediumService
  def self.url_for_user(user)
    "https://medium.com/@#{user}/latest"
  end

  def self.json_for_user(user)
    JSON.generate new(user: user).to_h
  end

  def initialize(user: user)
    @user = user
  end

  def url
    self.class.url_for_user @user
  end

  def content
    @content ||= RestClient.get url
  end

  def html_document
    @html_document ||= Nokogiri::HTML(content)
  end

  def post_elements
    html_document.css("div.screenContent div.u-backgroundWhite .blockGroup--posts.blockGroup--latest .block-content")
  end

  def items
    post_elements.map do |item|
      MediumFeedItem.from_item item
    end
  end

  def count
    post_elements.size
  end

  def profile_url
    "https://medium.com/@#{@user}"
  end

  def background_image_url
    html_document.at("meta[property='og:image']")["content"]
  end

  def to_h
    {
      items: items.map(&:to_h),
      profile_url: profile_url,
      background_image_url: background_image_url,
    }
  end
end

class MediumFeedItem
  attr_reader :title, :url, :time

  def self.from_item(item)
    anchor = item.at("h3.block-title a")
    new title: anchor.text,
          url: url_for(anchor["href"]),
         time: item.at(".block-postMeta span.readingTime").text
  end

  def self.url_for(string)
    if string =~ /^http:/
      string
    else
      "https://medium.com#{string}"
    end
  end

  def initialize(title: title, url: url, time: time)
    @title = title
    @url = url
    @time = time
  end

  def to_h
    {
      title: title,
      url: url,
      time: time,
    }
  end
end
