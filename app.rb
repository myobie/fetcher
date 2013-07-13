require 'sinatra'
require 'json'
require './support'

services :github, :medium, :instagram

get "/:user", subdomain: 'medium' do
  jsonp MediumService.json_for_user(params[:user])
end

get "/:user", subdomain: 'github' do
  jsonp GithubService.json_for_user(params[:user])
end

get "/:user", subdomain: 'instagram' do
  jsonp InstagramService.json_for_user(params[:user])
end
