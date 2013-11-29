# Sign in with Twitter sample

This is a minimal, ruby standalone web app to help you understand how to enable the users of your website to Sign in with their Twitter accounts.

* built as a simple Sinatra web app
* easy to install and play
* no dependency with external databases
* uses simple_oauth gem to enable free choice of HTTP client
* code comments linked to official Twitter docs

## Getting started

The requirement is to have ruby and bundler installed.

1. Create an app at [dev.twitter.com/apps](https://dev.twitter.com/apps) with:
    * read and write permission
    * callback set to http://dev.yoursite.com:4567/callback (add `127.0.0.1   dev.yoursite.com` entry to your local `/etc/hosts`)
    * Sign in with Twitter option checked
2. Clone this repo
3. Run `bundle install` to install dependencies
4. Rename `config/twitter_oauth.yml.sample` to `config/twitter_oauth.yml`
5. Fill `twitter_oauth.yml` with your app consumer key and consumer secret got at step 1
6. Optionally, change the var ACCOUNT_TO_FOLLOW in `app.rb` to set what account will be followed
7. Run `sign_in_start` script
8. Open http://dev.yoursite.com:4567 in your browser

## The web app

This web app simply require the user to Sign in with Twitter to be able to access "awesome" features. The features provided are the ability to create a automatic follow to an account (see step 6 above) or just to check the logged user info, which are resources only available if users authorize your app to have access to it.

**Please, take into account that this sample web app is intended only for educational purposes. I do not recommend to use it as is in production.**

## The code

This app code is full of comments explaining what's happening in high level and linking to the official docs. The signing in implementation is concentrated in `lib/twitter_sign_in.rb` file, and `app.rb` file implements the high level flow of authentication.

Data persistence is achieved with [Daybreak](http://propublica.github.io/daybreak/) gem and a default `db/signin.db` is used to store tokens and user info.

At frontend side, I tried to keep it simple and just used Twitter bootstrap. All views and layouts are in `views` folder.

I built this app using ruby 2, but it may work in other versions as well. Let me know if you have any problems to use it.
