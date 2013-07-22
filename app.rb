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
  erb :"index.html"
end
