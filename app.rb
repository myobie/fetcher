require 'sinatra'
require 'json'
require './support'

services :github, :medium, :instagram, :tumblr

get "/:user", subdomain: 'medium' do
  jsonp MediumService.json_for_user(params[:user])
end

get "/:user", subdomain: 'github' do
  jsonp GithubService.json_for_user(params[:user])
end

get "/:user", subdomain: 'instagram' do
  jsonp InstagramService.json_for_user(params[:user])
end

get "/:user", subdomain: 'tumblr' do
  jsonp TumblrService.json_for_user(params[:user])
end
