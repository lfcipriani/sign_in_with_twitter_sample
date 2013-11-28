require "net/https"
require "simple_oauth"

class TwitterSignIn

  class << self
    def configure
      @oauth = YAML.load_file(TWITTER)
    end

    def request_token
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

      db = Daybreak::DB.new DATABASE
      db.lock { db[obj["oauth_token"]] = obj }
      db.close

      return obj["oauth_token"]
    end

    def authenticate_url(query) 
      "https://api.twitter.com/oauth/authenticate?oauth_token=" + query
    end

    def access_token(oauth_token, oauth_verifier)

      db = Daybreak::DB.new DATABASE
      if dbtoken = db[oauth_token]

        oauth = @oauth.dup
        oauth[:token] = oauth_token
        oauth[:token_secret] = dbtoken["oauth_token_secret"]

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

        dbtoken["access_token"] = obj["oauth_token"]
        dbtoken["access_token_secret"] = obj["oauth_token_secret"]
        db.lock { db[oauth_token] = dbtoken }
        db.close

      else
        oauth_token = nil
      end

      return oauth_token
    end
    
    def verify_credentials(oauth_token)
      db = Daybreak::DB.new DATABASE

      if dbtoken = db[oauth_token]

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

        user.merge! dbtoken 
        db.lock { db[user["screen_name"]] = user }
        db.close

        result = user

      else
        result = nil
      end

      return result
    end

    def request(method, uri, params, oauth)
      uri = URI.parse(uri.to_s)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      #http.set_debug_output($stdout)

      req = (method == :post ? Net::HTTP::Post : Net::HTTP::Get).new(uri.request_uri)
      req.body = params.to_a.map { |x| "#{x[0]}=#{x[1]}" }.join("&")
      req["Host"] = "api.twitter.com"
      req["Authorization"] = SimpleOAuth::Header.new(method, uri.to_s, params, oauth)
      
      http.request(req)
    end

  end
end
