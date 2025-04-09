require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'


enable :sessions
output = []

# Database connection
DB = SQLite3::Database.new "db/Tabeller.db" 
DB.results_as_hash = true

get('/') do
  @ads = DB.execute("SELECT Advertisement.*, Cars.brand, Cars.model FROM Advertisement JOIN Cars ON Advertisement.car_id = Cars.Id")
  slim :index
end


get('/Advertisement') do
  
  slim :Advertisement
end

get('/loggin') do
  slim :loggin
end




# Använder '/create_advertisement'för att skapa en nya annonser
post '/create_advertisement' do
  # parametrar 
  brand = params[:brand]
  model = params[:model]
  title = params[:title]
  description = params[:description]
  price = params[:price]
  picture = params[:picture]

  # Spara i Cars 
  DB.execute("INSERT INTO Cars (brand, model) VALUES (?, ?)", [brand, model])

  # Hämta car_id 
  car_id = DB.last_insert_row_id

  # Spara i Advertisement 
  DB.execute("INSERT INTO Advertisement (title, description, price, picture, car_id) VALUES (?, ?, ?, ?, ?)", [title, description, price, picture, car_id])

  
  redirect '/'

end 

post '/delete_advertisement' do
  ad_id = params[:id].to_i
  puts "Försöker ta bort annons med id: #{ad_id}"

  DB.execute("DELETE FROM Advertisement WHERE Id = ?", ad_id)

  redirect '/'
end


# dasdasda