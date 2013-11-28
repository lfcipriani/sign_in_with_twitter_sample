# Base libs
require "rubygems"
require "sinatra"
# Important libs
require "json"
require "uri"
require "yaml"
require "daybreak"
# App libs
require File.expand_path(File.dirname(__FILE__) + '/lib/twitter_sign_in')
# Constants declarations
DATABASE = File.expand_path(File.dirname(__FILE__) + '/db/signin.db')
TWITTER  = File.expand_path(File.dirname(__FILE__) + "/config/twitter_oauth.yml")
ACCOUNT_TO_FOLLOW = "lfcipriani"

# Configurations
TwitterSignIn.configure

configure do
  enable :sessions
  # setting a random secret
  set :session_secret, 'this is super secret, unless you read this file'
end

helpers do
  def user_logged
    user = nil
    if session[:user]
      db = Daybreak::DB.new DATABASE
      user = db[session[:user]]
      db.close
    end
    user
  end
end

# Index
get '/' do
  erb :index
end

# Sign in with Twitter
get '/signin' do
  token = TwitterSignIn.request_token
  redirect TwitterSignIn.authenticate_url(token)
end

get '/callback' do
  token = TwitterSignIn.access_token(params["oauth_token"], params["oauth_verifier"])
  if token
    user = TwitterSignIn.verify_credentials(token)
    session[:user] = user["screen_name"]
    session[:info] = {
      :avatar => user["profile_image_url"],
      :name   => user["name"],
      :bio    => user["description"]
    }
  else
    logger.info "User didn't authorized us"
  end

  erb :awesome
end

# Protected features
get '/awesome_features' do
  if user_logged.nil?
    erb :forbidden
  else
    @account = ACCOUNT_TO_FOLLOW
    erb :awesome
  end
end

get '/awesome_features/follow' do
  if user_logged.nil?
    erb :forbidden
  else
    db = Daybreak::DB.new DATABASE
    dbtoken = db[session[:user]]
    @oauth = YAML.load_file(TWITTER)
    oauth = @oauth.dup
    oauth[:token] = dbtoken["access_token"]
    oauth[:token_secret] = dbtoken["access_token_secret"]

    response = TwitterSignIn.request(
      :post, 
      "https://api.twitter.com/1.1/friendships/create.json",
      {:screen_name => ACCOUNT_TO_FOLLOW},
      oauth
    )

    user = JSON.parse(response.body)
    db.close

    @info = JSON.pretty_generate(user_logged)
    erb :awesome_follow
  end
end

get '/awesome_features/info' do
  if user_logged.nil?
    erb :forbidden
  else
    @info = JSON.pretty_generate(user_logged)
    erb :awesome_info
  end
end

# Logout
get '/logout' do
  session[:user] = nil
  session[:info] = nil

  erb :index
end
