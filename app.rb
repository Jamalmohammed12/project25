require 'sinatra'
require 'slim'
require 'sqlite3'
require 'sinatra/reloader'
require 'bcrypt'

enable :sessions

# Database connection
DB = SQLite3::Database.new "db/Tabeller.db"
DB.results_as_hash = true

# Helpers
helpers do
  def current_user
    return nil unless session[:user_id]
    DB.execute("SELECT * FROM User WHERE id = ?", session[:user_id]).first
  end

  def logged_in?
    !current_user.nil?
  end

  def admin?
    current_user && current_user["Role"].to_i == 1
  end
end

# Before-filter
before ['/advertisements', '/advertisements/:id/edit', '/advertisements/:id/update', '/advertisements/:id/delete'] do
  redirect '/loggin' unless logged_in?
end

# Startsida
get('/') do
  @ads = DB.execute("
    SELECT Advertisement.*, Cars.brand, Cars.model, User.Username 
    FROM Advertisement 
    JOIN Cars ON Advertisement.car_id = Cars.Id
    JOIN User ON Advertisement.user_id = User.id
  ")
  slim :index
end

# Formulär: skapa annons
get('/advertisements/new') do
  @form_data = {}
  slim :Advertisement
end

# Inloggningsformulär
get('/loggin') do
  slim :loggin
end

# Registreringsformulär
get('/register') do
  slim :register
end

# Registrering
post '/register' do
  username = params[:username].strip
  password = params[:password].strip

  if username.empty? || password.empty?
    return "Användarnamn och lösenord krävs!"
  end

  hashed_password = BCrypt::Password.create(password)

  begin
    DB.execute("INSERT INTO User (Username, password_digest, Role) VALUES (?, ?, ?)", [username, hashed_password, 0])
    redirect '/loggin'
  rescue SQLite3::ConstraintException
    "Användarnamnet är redan registrerat"
  end
end

# Inloggning
post '/loggin' do
  username = params[:username]
  password = params[:password]

  user = DB.execute("SELECT * FROM User WHERE Username = ?", [username]).first

  if user && BCrypt::Password.new(user['password_digest']) == password
    session[:user_id] = user['id']
    redirect '/'
  else
    "Fel användarnamn eller lösenord"
  end
end

# Utloggning
get '/logout' do
  session.clear
  redirect '/'
end

# Skapa ny annons
post '/advertisements' do
  brand = params[:brand].strip
  model = params[:model].strip
  title = params[:title].strip
  description = params[:description].strip
  price = params[:price].strip
  picture = params[:picture].strip
  user_id = session[:user_id]

  if brand.empty? || model.empty? || title.empty? || description.empty? || price.empty?
    @error = "Alla fält utom bild måste fyllas i!"
    @form_data = params
    return slim :Advertisement
  end

  begin
    if Float(price) <= 0
      @error = "Priset måste vara ett positivt tal!"
      @form_data = params
      return slim :Advertisement
    end
  rescue ArgumentError
    @error = "Priset måste vara ett giltigt tal!"
    @form_data = params
    return slim :Advertisement
  end

  DB.execute("INSERT INTO Cars (brand, model) VALUES (?, ?)", [brand, model])
  car_id = DB.last_insert_row_id

  DB.execute("INSERT INTO Advertisement (title, description, price, picture, car_id, user_id) VALUES (?, ?, ?, ?, ?, ?)",
             [title, description, price, picture, car_id, user_id])

  redirect '/'
end

# Ta bort annons
delete '/advertisements/:id' do
  ad_id = params[:id].to_i
  ad = DB.execute("SELECT * FROM Advertisement WHERE Id = ?", ad_id).first

  if !admin? && ad["user_id"].to_i != session[:user_id].to_i
    halt(403, "Du får inte ta bort denna annons.")
  end

  DB.execute("DELETE FROM Advertisement WHERE Id = ?", ad_id)
  redirect '/'
end

# Redigera annons – formulär
get '/advertisements/:id/edit' do
  id = params[:id].to_i
  @ad = DB.execute("SELECT * FROM Advertisement WHERE Id = ?", id).first

  if @ad.nil?
    halt(404, "Annonsen hittades inte.")
  end

  if !admin? && @ad["user_id"].to_i != session[:user_id].to_i
    halt(403, "Du får inte redigera denna annons.")
  end

  slim :edit_advertisement
end

# Uppdatera annons
patch '/advertisements/:id' do
  id = params[:id].to_i
  ad = DB.execute("SELECT * FROM Advertisement WHERE Id = ?", id).first

  if ad.nil?
    halt(404, "Annonsen finns inte.")
  end

  if !admin? && ad["user_id"].to_i != session[:user_id].to_i
    halt(403, "Du får inte uppdatera denna annons.")
  end

  title = params[:title].strip
  description = params[:description].strip
  price = params[:price].strip

  if title.empty? || description.empty? || price.empty?
    @error = "Fält får inte vara tomma!"
    @ad = {'Id' => id, 'title' => title, 'description' => description, 'price' => price}
    return slim :edit_advertisement
  end

  begin
    Float(price)
  rescue ArgumentError
    @error = "Priset måste vara ett giltigt tal!"
    @ad = {'Id' => id, 'title' => title, 'description' => description, 'price' => price}
    return slim :edit_advertisement
  end

  DB.execute("UPDATE Advertisement SET title = ?, description = ?, price = ? WHERE Id = ?", [title, description, price, id])
  redirect '/'
end

# Adminpanel
get '/admin_panel' do
  halt(403, "Du är inte admin") unless admin?
  @users = DB.execute("SELECT id, Username, Role FROM User")
  slim :admin_panel
end

# Växla användarroll
post '/admin_panel/:id/toggle_role' do
  halt(403, "Du är inte admin") unless admin?
  user_id = params[:id].to_i

  user = DB.execute("SELECT * FROM User WHERE id = ?", user_id).first
  halt(404, "Användaren finns inte") unless user

  new_role = user["Role"].to_i == 1 ? 0 : 1
  DB.execute("UPDATE User SET Role = ? WHERE id = ?", [new_role, user_id])

  redirect '/admin_panel'
end

# Ta bort användare
post '/admin_panel/:id/delete' do
  halt(403, "Du är inte admin") unless admin?
  user_id = params[:id].to_i

  DB.execute("DELETE FROM Advertisement WHERE user_id = ?", user_id)
  DB.execute("DELETE FROM User WHERE id = ?", user_id)

  redirect '/admin_panel'
end
