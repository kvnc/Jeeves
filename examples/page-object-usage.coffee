Jeeves = require '../lib/jeeves'
should = require 'should'
GuineaPageObject = require './page-objects/GuineaPageObject'

destinationUrl = 'http://admc.io/wd/test-pages/guinea-pig.html'
browser = null

describe 'regular mocha usage', ->
  @timeout 10000

  before (done) ->
    browser = new Jeeves
      wdLogging: true
      wdCapabilities:
        browserName:'chrome'
      logger: console
    @guineaPage = new GuineaPageObject

    browser.init done

  beforeEach (done) -> browser.loadPage 'http://admc.io/wd/test-pages/guinea-pig.html', done

  after (done) ->
    browser.quit (err) ->
      console.log 'Webdriving has completed'
      done err

  it 'should retrieve the page title', (done) ->
    @guineaPage.title (err, title) ->
      title.should.containEql 'WD'
      done err

  it 'submit element should be clicked', (done) ->
    browser.namedSteps
      submit: (next) ->
        @guineaPage.submitForm next
      checkUrl: (next) ->
        browser.getCurrentUrl (err, url) ->
        url.should.include '&submit'
        next err
    , done

  it 'should click link and load new url', (done) ->
    browser.namedSteps
      clickLink: (next) ->
        @guineaPage.clickLink next
      waitForUrl: (next) ->
        browser.waitForUrlToChange /guinea-pig2/i, true, (err, newUrl) ->
          newUrl.should.not.equal destinationUrl
          next err
    , done
