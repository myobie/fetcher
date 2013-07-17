require 'sinatra'
require './support'

services :github, :medium, :instagram, :tumblr, :dribbble

get "/:user", subdomain: 'medium' do
  MediumService.json_for_user(params[:user])
end

get "/:user", subdomain: 'github' do
  GithubService.json_for_user(params[:user])
end

get "/:user", subdomain: 'instagram' do
  InstagramService.json_for_user(params[:user])
end

get "/:user", subdomain: 'tumblr' do
  TumblrService.json_for_user(params[:user])
end

get "/:user", subdomain: 'dribbble' do
  DribbbleService.json_for_user(params[:user])
end
