class TrendingController < ApplicationController
  include ActionController::Live

  Mime::Type.register "text/event-stream", :stream

  def index 
    # set global time_span variable 
    # (since no DB is being used)
    $time_span_global = params[:time_span].to_i if params[:time_span].present?
    time_span = $time_span_global

    # if time_span not set by user, 
    # use default = 3 mins
    time_span = 3 if $time_span_global.nil?
  	@top_ten_retweets = []

    # Twitter authentication using OAuth
    TweetStream.configure do |config|
      config.consumer_key = ENV['API_KEY'] 
      config.consumer_secret = ENV['API_SECRET'] 
      config.oauth_token = ENV['ACCESS_TOKEN'] 
      config.oauth_token_secret = ENV['ACCESS_TOKEN_SECRET'] 
      config.auth_method = :oauth
      config.parser = :yajl
    end

    # variable initiations
    top_ten_retweet_info = {}
    top_ten_retweet_info[:top_ten_retweets] = []
    top_ten_retweet_info[:min_retweet_count] = 0

    # send response as json 
    # formateed stream
    respond_to do |format|
      format.html
      format.stream {
        response.headers['Content-Type'] = 'text/event-stream'
        begin
          # open twitter-stream api client
          TweetStream::Client.new.sample do |status|

            # obtain the latest top_ten retweet
            # based on current input tweet
            top_ten_retweet_info = current_top_ten_retweets(status, top_ten_retweet_info, time_span)
            
            @top_ten_retweets = top_ten_retweet_info[:top_ten_retweets]
            
            # prepare data to send to client-side
            data = {}
            data[:tweet_data] = []
            @top_ten_retweets.each {|tweet| data[:tweet_data] << {created_at: tweet.created_at, tweet_count: tweet.retweeted_status.retweet_count, text: tweet.text} }

            # write to stream
            response.stream.write "data: #{data.to_json}\n\n"
          end
        rescue IOError # Raised when browser interrupts the connection
        ensure
          # Prevents stream from being open forever
          response.stream.close 
        end
      }
    end
  end

private

  def current_top_ten_retweets(status, top_ten_retweet_info, time_span)

    # instentiate local variables
    top_ten_retweets = top_ten_retweet_info[:top_ten_retweets]
    min_retweet_count = top_ten_retweet_info[:min_retweet_count]
    retweet_count_sorted = []

    # for the first 10 tweets received
    # collect them if they are a retweet
    # and within the given time_span
    top_ten_retweets << status if (!status.retweeted_status.nil?) and (top_ten_retweets.count < 10) and (status.created_at + 60 * time_span >= Time.now)

    # remove outdated tweets 
    # (past the time_span)
    top_ten_retweets.delete_if {|tweet| tweet.created_at + 60*time_span < Time.now }

    # if we already have 10 top retweets
    # only add new ones if they have higher
    # retweet count than any in the collection.
    if (top_ten_retweets.count == 10) and (!status.retweeted_status.nil?) and (status.created_at + 60 * time_span >= Time.now)
      
      # set min_retweet_count
      retweet_count_sorted = top_ten_retweets.sort {|a,b| a.retweeted_status.retweet_count <=> b.retweeted_status.retweet_count}.reverse
      min_retweet_count = retweet_count_sorted.last.retweeted_status.retweet_count
      
      # for any new tweet received, check if the tweet's 
      # retweet count is greater than the minimum retweet count
      # in the collection.
      if status.retweeted_status.retweet_count > min_retweet_count
        top_ten_retweets.each {|tweet| retweet_count_sorted << tweet if tweet.created_at + 60 * time_span >= Time.now }

        # if it is greater than the minimum retweet_count, 
        # add it to the current top_ten_retweets 
        # and sort based on retweet_count.
        retweet_count_sorted << status
        retweet_count_sorted = retweet_count_sorted.sort {|a,b| a.retweeted_status.retweet_count <=> b.retweeted_status.retweet_count}.reverse

        # take the first 10 in descending order
        retweet_count_sorted = retweet_count_sorted.first 10

        # # update the minimum value of retweeted_count
        # min_retweet_count = retweet_count_sorted.last.retweeted_status.retweet_count

        # order top_ten_retweets by time
        top_ten_retweets = retweet_count_sorted.sort {|a,b| a.created_at <=> b.created_at}
      end      
    end

    top_ten_retweet_info[:top_ten_retweets] = top_ten_retweets
    top_ten_retweet_info[:min_retweet_count] = min_retweet_count
    top_ten_retweet_info
  end

end
