require 'sinatra'
require './support'

services :github, :medium, :instagram, :tumblr, :dribbble

get "/:user", subdomain: 'medium' do
  cache { MediumService.json_for_user(params[:user]) }
end

get "/:user", subdomain: 'github' do
  cache { GithubService.json_for_user(params[:user]) }
end

get "/:user", subdomain: 'instagram' do
  cache { InstagramService.json_for_user(params[:user]) }
end

get "/:user", subdomain: 'tumblr' do
  cache { TumblrService.json_for_user(params[:user]) }
end

get "/:user", subdomain: 'dribbble' do
  cache { DribbbleService.json_for_user(params[:user]) }
end

get "/" do
  content_type :html
  erb :index
end

__END__

@@index

<style>
  body {
    font: 18px/1.6 Helvetica Neue, Arial, sans-serif;
    color: #222;
  }

  h1, h2, h3, p, ul, li {
    font-size: 18px;
    margin: 0 0 1em;
  }

  li {
    margin: 0;
    padding: 0;
  }

  h2 {
    margin-top: 3em;
  }
</style>

<h1>The Fetcher</h1>

<h2>What is this?</h2>
<p>I wanted to be able to include some different stats from different services on my static html website, so I built this scraper of sorts. I hope to make it better overtime, maybe even get some other people using it.

<h2>Usage</h2>
<p>Visit http://:service.fetcher.nathanherald.com/:username<br>
(example http://dribbble.fetcher.nathanherald.com/myobie)

<h3>jsonp</h3>
<p>Every endpoint supports jsonp, just append a callback params like so:<br>
(example <%= link "http://dribbble.fetcher.nathanherald.com/myobie?callback=processDribble" %>)

<h2>Services Supported</h2>
<ul>
<li>Dribbble
<li>Github
<li>Instagram
<li>Medium
<li>Tumblr
</ul>

<h2>Source &amp; Support</h2>
<p><%= link "https://github.com/myobie/fetcher", "Fork me" %> on GitHub.
