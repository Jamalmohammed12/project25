require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions
output=[]



get('/') do
    slim(:start)
  end

