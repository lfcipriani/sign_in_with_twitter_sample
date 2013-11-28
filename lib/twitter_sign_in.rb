require "net/https"
require "simple_oauth"

# This class implements the requests that should 
# be done to Twitter to be able to authenticate
# users with Twitter credentials
class TwitterSignIn

  class << self
    def configure
      @oauth = YAML.load_file(TWITTER)
    end

    # See https://dev.twitter.com/docs/auth/implementing-sign-twitter (Step 1)
    def request_token

      # The request to get request tokens should only
      # use consumer key and consumer secret, no token
      # is necessary
      response = TwitterSignIn.request(
        :post, 
        "https://api.twitter.com/oauth/request_token",
        {},
        @oauth
      )

      obj = {}
      vars = response.body.split("&").each do |v|
        obj[v.split("=").first] = v.split("=").last
      end

      # oauth_token and oauth_token_secret should
      # be stored in a database and will be used
      # to retrieve user access tokens in next requests
      db = Daybreak::DB.new DATABASE
      db.lock { db[obj["oauth_token"]] = obj }
      db.close

      return obj["oauth_token"]
    end

    # See https://dev.twitter.com/docs/auth/implementing-sign-twitter (Step 2)
    def authenticate_url(query) 
      # The redirection need to be done with oauth_token
      # obtained in request_token request
      "https://api.twitter.com/oauth/authenticate?oauth_token=" + query
    end

    # See https://dev.twitter.com/docs/auth/implementing-sign-twitter (Step 3)
    def access_token(oauth_token, oauth_verifier)

      # To request access token, you need to retrieve
      # oauth_token and oauth_token_secret stored in 
      # database
      db = Daybreak::DB.new DATABASE
      if dbtoken = db[oauth_token]

        # now the oauth signature variables should be
        # your app consumer keys and secrets and also
        # token key and token secret obtained in request_token
        oauth = @oauth.dup
        oauth[:token] = oauth_token
        oauth[:token_secret] = dbtoken["oauth_token_secret"]

        # oauth_verifier got in callback must 
        # to be passed as body param
        response = TwitterSignIn.request(
          :post, 
          "https://api.twitter.com/oauth/access_token",
          {:oauth_verifier => oauth_verifier},
          oauth
        )

        obj = {}
        vars = response.body.split("&").each do |v|
          obj[v.split("=").first] = v.split("=").last
        end

        # now the we got the access tokens, store it safely
        # in database, you're going to use it later to
        # access Twitter API in behalf of logged user
        dbtoken["access_token"] = obj["oauth_token"]
        dbtoken["access_token_secret"] = obj["oauth_token_secret"]
        db.lock { db[oauth_token] = dbtoken }

      else
        oauth_token = nil
      end

      db.close
      return oauth_token
    end
    
    # This is a sample Twitter API request to 
    # make usage of user Access Token
    # See https://dev.twitter.com/docs/api/1.1/get/account/verify_credentials
    def verify_credentials(oauth_token)
      db = Daybreak::DB.new DATABASE

      if dbtoken = db[oauth_token]

        # see that now we use the app consumer variables
        # plus user access token variables to sign the request
        oauth = @oauth.dup
        oauth[:token] = dbtoken["access_token"]
        oauth[:token_secret] = dbtoken["access_token_secret"]

        response = TwitterSignIn.request(
          :get, 
          "https://api.twitter.com/1.1/account/verify_credentials.json",
          {},
          oauth
        )

        user = JSON.parse(response.body)

        # Just saving user info to database
        user.merge! dbtoken 
        db.lock { db[user["screen_name"]] = user }

        result = user

      else
        result = nil
      end

      db.close
      return result
    end

    # Generic request method used by methods above
    def request(method, uri, params, oauth)
      uri = URI.parse(uri.to_s)

      # always use SSL, you are dealing with other users data
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      # uncomment line below for debug purposes
      #http.set_debug_output($stdout)

      req = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri.request_uri)
      req.body = params.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join("&")
      req["Host"] = "api.twitter.com"

      # Oauth magic is done by simple_oauth gem.
      # This gem is enable you to use any HTTP lib
      # you want to connect in OAuth enabled APIs.
      # It only creates the Authorization header value for you
      # and you can assign it wherever you want
      # See https://github.com/laserlemon/simple_oauth
      req["Authorization"] = SimpleOAuth::Header.new(method, uri.to_s, params, oauth)
      
      http.request(req)
    end

  end
end
