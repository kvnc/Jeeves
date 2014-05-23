Jeeves = require '../lib/jeeves'
should = require 'should'

browser = new Jeeves
  wdLogging: true
  wdCapabilities:
    browserName:'chrome'
  logger: console

destinationUrl = 'http://admc.io/wd/test-pages/guinea-pig.html'

browser.init ->
  browser.loadPageAndWait destinationUrl, (err, loadedUrl) ->
    loadedUrl.should.equal destinationUrl
    browser.getPageTitle (err, title) ->
      title.should.containEql 'WD'
      browser.clickElementById 'i am a link', (err) ->
        browser.waitForUrlToChange /guinea-pig2/i, true, (err, newUrl) ->
          newUrl.should.not.equal destinationUrl
          browser.quit (err) ->
            console.log 'Webdriving has completed'
