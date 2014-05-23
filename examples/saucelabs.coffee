Jeeves = require '../lib/jeeves'
should = require 'should'

username = process.env.SAUCE_USERNAME || "SAUCE_USERNAME"
accessKey = process.env.SAUCE_ACCESS_KEY || "SAUCE_ACCESS_KEY"

browser = new Jeeves
  wdLogging: true
  wdConfig:
    host: 'ondemand.saucelabs.com'
    port: 80
    username: username
    accessKey: accessKey
  wdCapabilities:
    browserName:'chrome'
    platform: 'LINUX'
    tags: ['examples']
    name: 'This is an example test'

  logger: console

destinationUrl = 'http://admc.io/wd/test-pages/guinea-pig.html'

browser.namedSteps
  startWebDriver: (next) ->
    browser.init next
  loadPage: (next) ->
    browser.loadPageAndWait destinationUrl, (err, loadedUrl) ->
      loadedUrl.should.equal destinationUrl
      next err
  checkTitle: (next) ->
    browser.getPageTitle (err, title) ->
      title.should.containEql 'WD'
      next err
  clickLink: (next) ->
    browser.clickElementById 'i am a link', next
  waitForUrl: (next) ->
    browser.waitForUrlToChange /guinea-pig2/i, true, (err, newUrl) ->
      newUrl.should.not.equal destinationUrl
      next err
  quit: (next) ->
    browser.quit (err) ->
      console.log 'Webdriving has completed'
      next err
