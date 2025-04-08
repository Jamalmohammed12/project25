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

  # get('/Advertisements') do
  #   db = SQLite3::Database.new("db/Tabeller.db")
  #   db.results_as_hash = true
  #   @result = db.execute("SELECT * FROM Advertisment")
  #   slim :index
  # end

 

   
