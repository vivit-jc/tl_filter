# encoding: utf-8

require 'rubygems'
require 'sinatra'
require 'oauth'
require 'twitter'
require 'pp'
 
# Sessionの有効化
enable :sessions

set :server, 'webrick'

# Twitter API情報の設定
YOUR_CONSUMER_KEY = "YluJnabpe3Zjnc2CR1ptiJCcW"
YOUR_CONSUMER_SECRET = "zuLj0BiQffcw0O9nBShfWNvrdzdOankPE33nrQk4EaFSoAoaL2"
# TwitterAPI ライブラリ 設定(1/2)
twitter_client = Twitter::REST::Client.new do |config|
  config.consumer_key = YOUR_CONSUMER_KEY
  config.consumer_secret = YOUR_CONSUMER_SECRET
end

def collect_with_max_id(collection=[], max_id=nil, &block)
  response = yield(max_id)
  collection += response
  response.empty? ? collection.flatten : collect_with_max_id(collection, response.last.id - 1, &block)
end

def oauth_consumer
  return OAuth::Consumer.new(YOUR_CONSUMER_KEY, YOUR_CONSUMER_SECRET, :site => "https://api.twitter.com")
end
 
def word_match?(text)
  ["コミケ","コミックマーケット","夏コミ","冬コミ","90","新刊","入稿","頒布","告知","おしながき","お品書き","表紙","委託","とら","虎","メロン","予約","pixiv"].each do |str|
    return true if(text.include?(str))
  end
  return false
end

# トップページ
get '/' do

  @tweet_button = <<EOS
  <a href="https://twitter.com/share" class="twitter-share-button">Tweet</a><script>!function(d,s,id){var js,fjs=d.getElementsByTagName(s)[0],p=/^http:/.test(d.location)?'http':'https';if(!d.getElementById(id)){js=d.createElement(s);js.id=id;js.src=p+'://platform.twitter.com/widgets.js';fjs.parentNode.insertBefore(js,fjs);}}(document, 'script', 'twitter-wjs');</script>
EOS

  haml :index, :format => :html5
end
 
# Twitter認証
get '/twitter/auth' do
  # callback先のURLを指定する 
#  callback_url = "http://localhost:4567/twitter/callback"
  callback_url = "https://oshinagaki.herokuapp.com/twitter/callback"
  request_token = oauth_consumer.get_request_token(:oauth_callback => callback_url)
 
  # セッションにトークンを保存
  session[:request_token] = request_token.token
  session[:request_token_secret] = request_token.secret
  redirect request_token.authorize_url
  #"test"
end
 
# Twitterからトークンなどを受け取り
get '/twitter/callback' do

  request_token = OAuth::RequestToken.new(oauth_consumer, session[:request_token], session[:request_token_secret])
 
  # OAuthで渡されたtoken, verifierを使って、tokenとtoken_secretを取得
  access_token = nil
  begin
    access_token = request_token.get_access_token(
      {},
      :oauth_token => params[:oauth_token],
      :oauth_verifier => params[:oauth_verifier])
  rescue OAuth::Unauthorized => @exception
    # 本来はエラー画面を表示したほうが良いが、今回はSinatra標準のエラー画面を表示
    haml :error, :format => :html5
  end
 
  # TwitterAPI ライブラリ 設定(2/2)
  twitter_client = Twitter::REST::Client.new do |config|
    config.consumer_key = YOUR_CONSUMER_KEY
    config.consumer_secret = YOUR_CONSUMER_SECRET
    config.access_token = access_token.token
    config.access_token_secret = access_token.secret
  end

  def twitter_client.get_all_tweets(user)
    collect_with_max_id do |max_id|
      options = {count: 200, include_rts: true}
      options[:max_id] = max_id unless max_id.nil?
      user_timeline(user, options)
    end
  end

  # タイムラインの情報を取得、表示
  begin
    @twarray = twitter_client.get_all_tweets(twitter_client.user)
    @count = @twarray.size
    @twarray = @twarray.select{|p|word_match?(p.full_text)}
    haml :scan, :format => :html5

  rescue Twitter::Error::TooManyRequests => @error
    @count = @twarray.size
    @twarray = @twarray.select{|p|word_match?(p.full_text)}
    if(@twarray.size > 0)
      haml :scan, :format => :html5
    else
      haml :error, :format => :html5
    end
  end

end