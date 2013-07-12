require 'sinatra'
require 'json'
require './support'

services :github, :medium

get "/:user", subdomain: 'medium' do
  jsonp MediumService.json_for_user(params[:user])
end

get "/:user", subdomain: 'github' do
  jsonp GithubService.json_for_user(params[:user])
end
