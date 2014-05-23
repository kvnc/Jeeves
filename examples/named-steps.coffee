Jeeves = require '../lib/jeeves'
should = require 'should'

browser = new Jeeves
  wdLogging: true
  wdCapabilities:
    browserName:'chrome'
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
