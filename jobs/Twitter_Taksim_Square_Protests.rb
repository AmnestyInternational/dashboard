#!/usr/bin/env ruby
require 'yaml'
require 'tiny_tds'
require 'date'
 
yml = YAML::load(File.open('lib/db_settings.yml'))['prod_settings']

SCHEDULER.every '10m', :first_in => 213 do |job|
  tweetusers = []

  client = TinyTds::Client.new(:username => yml['username'], :password => yml['password'], :host => yml['host'])
  result = client.execute("
    USE externaldata

    SELECT TOP 18 TA.term 'user', COUNT(DISTINCT(TA.tweet_id)) 'RTCount'
    FROM
      Tweets AS T1
      INNER JOIN
      TweetsAnatomize AS TA
      ON '@' + T1.usr = TA.term
      INNER JOIN
      Tweets AS T2
      ON TA.tweet_id = T2.id
    WHERE
      T2.created >= DATEADD(HOUR, -24, GETDATE()) AND
      T1.city = 'Gezi'
    GROUP BY TA.term
    ORDER BY RTCount DESC")

  result.each do |row|
    tweetusers << {:label=>row['user'], :value=>row['RTCount']}
  end

  send_event('Twitter_Taksim_Square_Influential_Users', { items: tweetusers })

end



SCHEDULER.every '60m', :first_in => 313 do |job|
  twitter_trends = []

  client = TinyTds::Client.new(:username => yml['username'], :password => yml['password'], :host => yml['host'])
  result = client.execute("
    USE externaldata

    SELECT TOP 7 TA.term, COUNT(TA.term) 'Count'
    FROM
      Tweets AS T
      INNER JOIN
      tweetsanatomize AS TA
      ON T.id = TA.tweet_id
    WHERE
      TA.term LIKE '#%' AND
      T.created > DATEADD(HOUR, -24, GETDATE())
    GROUP BY TA.term
    ORDER BY COUNT(TA.term) DESC")

  result.each do |row|
    twitter_trends << {:label=>row['term'], :value=>row['Count']}
  end

  send_event('Twitter_Taksim_Square_trending_hashtags', { items: twitter_trends })
end



def seconds_since_midnight
  (Time.now.hour * 3600) + (Time.now.min * 60) + (Time.now.sec)
end

starttime = seconds_since_midnight - (36 * 60 * 10)

points = []
(1..36).each do | i |
  points << { x: (i * 60 * 10) + starttime, y: 0 }
end

SCHEDULER.every '10m', :first_in => 317 do |job|
  points.shift

  client = TinyTds::Client.new(:username => yml['username'], :password => yml['password'], :host => yml['host'])
  result = client.execute("
    USE externaldata
    SELECT COUNT(DISTINCT(usr_id)) 'count'
    FROM Tweets
    WHERE
      city = 'Gezi' AND
      text LIKE '%tear%gas%' AND
      created > DATEADD(MINUTE, -10, GETDATE())")

  points << { x: seconds_since_midnight, y: result.first['count'] }

  send_event('Twitter_Taksim_Square_Tear_Gas_Usage', points: points)

end




SCHEDULER.every '10m', :first_in => 295 do |job|
  client = TinyTds::Client.new(:username => yml['username'], :password => yml['password'], :host => yml['host'], :timeout => 120000)
  results = client.execute("
    USE externaldata
    SELECT 
      (SELECT COUNT(DISTINCT(usr_id))
      FROM Tweets
      WHERE
        city = 'Gezi' AND
        created > DATEADD(MINUTE, -60, GETDATE())) 'lasthour',
      (SELECT COUNT(DISTINCT(usr_id))
      FROM Tweets
      WHERE
        city = 'Gezi' AND
        created < DATEADD(MINUTE, -60, GETDATE()) AND
        created > DATEADD(MINUTE, -120, GETDATE())) 'previoushour'")

  tweeters = results.first

  send_event('Twitter_Taksim_Square_Tweeters', { current: tweeters['lasthour'], last: tweeters['previoushour'] })
end


SCHEDULER.every '10m', :first_in => 125 do |job|
  populartweets = []

  client = TinyTds::Client.new(:username => yml['username'], :password => yml['password'], :host => yml['host'])
  result = client.execute("
  USE externaldata

  SELECT TOP 5 usr_name, text, profile_image_url
  FROM Tweets
  WHERE
    RIGHT(text,25) IN (
      SELECT TOP 5 RIGHT(text,25)
      FROM Tweets
      WHERE
        imported >= DATEADD(WEEK, -1, GETDATE()) AND
        city = 'Gezi'
      GROUP BY RIGHT(text,25)
      ORDER BY COUNT(id) DESC) AND
    city = 'Gezi'
  ORDER BY created DESC")

  result.each do |row|
    populartweets << {:name=>row['usr_name'], :body=>row['text'], :avatar=>row['profile_image_url']}
  end

  send_event('Tweets_From_Taksim_Square', comments: populartweets)
end



SCHEDULER.every '10m', :first_in => 262 do |job|
  http = Net::HTTP.new('ajax.googleapis.com')
  response = http.request(Net::HTTP::Get.new("/ajax/services/feed/load?v=1.0&q=https://news.google.ca/news/feeds?q=Istanbul+protests&safe=off&cr=countryCA&bav=on.2,or.r_cp.r_qf.&bvm=bv.47244034,d.aWM&ion=1&biw=1440&bih=813&um=1&ie=UTF-8&output=rss"))
  newsarticles = JSON.parse(response.body)['responseData']['feed']['entries']
 
  if newsarticles
    newsarticles.map! do |article| 
      { name: article['title'], body: article['contentSnippet'] }
    end
  
    send_event('Google_News_feed_Taksim_Square', comments: newsarticles)
  end
end

# http://ajax.googleapis.com/ajax/services/feed/load?v=1.0&q=https://news.google.ca/news/feeds?q=Istanbul+protests&safe=off&cr=countryCA&bav=on.2,or.r_cp.r_qf.&bvm=bv.47244034,d.aWM&ion=1&biw=1440&bih=813&um=1&ie=UTF-8&output=rss












