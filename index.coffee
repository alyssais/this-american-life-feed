async = require "async"
request = require "request"
cheerio = require "cheerio"
app = require("express")()

EPISODES_PER_PAGE = 2**31-1
EPISODES_URL = "http://api.thisamericanlife.org/iphone/episodes.json?version=2&per_page=#{EPISODES_PER_PAGE}"
FEED_URL = "http://feed.thisamericanlife.org/talpodcast"

app.get "/", (req, res) -> res.send()

app.get "/feed", (req, res) ->
  async.map [EPISODES_URL, FEED_URL],
    (url, done) -> request url, (error, _, body) -> done error, body
    (_, [rawEpisodes, rawFeed]) ->
      episodes = JSON.parse(rawEpisodes)
      feed = cheerio.load(rawFeed, xmlMode: true)

      feed("item").remove()

      items = for episode in episodes
        for date in episode.air_dates
          feed("<item>").append [
            feed("<title>").text(episode.title)
            feed("<link>").text(episode.url)
            feed("<description>").text(episode.description)
            feed("<pubDate>").text(episode.air_dates[0])
            feed("<dc:creator>").text("This American Life")
            feed("<guid>").attr(isPermaLink: "false").
              text("#{episode.id} at http://www.thisamericanlife.org")
            feed("<ns0:duration>").text [
              Math.floor episode.duration / 3600
              Math.floor episode.duration / 60 % 60
              Math.floor episode.duration % 3600
            ].map((x) -> if x < 10 then "0#{x}" else x).join(":")
            feed("<ns3:content>").attr(type: "audio/mpeg", url: episode.url)
            feed("<ns0:explicit>").text("no")
            feed("<ns0:subtitle>").text(episode.description)
            feed("<ns0:author>").text("This American Life")
            feed("<ns0:summary>").text(episode.description)
            feed("<ns2:origLink>").text(episode.url)
            feed("<enclosure>").
              attr(length: "0", type: "audio/mpeg", url: episode.mp3)
            feed("<ns2:origEnclosureLink>").text(episode.itunes)
          ]

      items = items.reduce (a, e) -> a.concat e
      feed("channel").append(items)

      res.append "Content-Type", "application/rss+xml"
      res.send feed.html()

app.listen process.env.PORT or 3456
