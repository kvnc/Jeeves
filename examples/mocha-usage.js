// Generated by CoffeeScript 1.7.1
(function() {
  var Jeeves, browser, destinationUrl, should;

  Jeeves = require('../lib/jeeves');

  should = require('should');

  destinationUrl = 'http://admc.io/wd/test-pages/guinea-pig.html';

  browser = null;

  describe('regular mocha usage', function() {
    this.timeout(10000);
    before(function(done) {
      browser = new Jeeves({
        wdLogging: true,
        wdCapabilities: {
          browserName: 'chrome'
        },
        logger: console
      });
      return browser.init(done);
    });
    beforeEach(function(done) {
      return browser.loadPage('http://admc.io/wd/test-pages/guinea-pig.html', done);
    });
    after(function(done) {
      return browser.quit(function(err) {
        console.log('Webdriving has completed');
        return done(err);
      });
    });
    it('should retrieve the page title', function(done) {
      return browser.getPageTitle(function(err, title) {
        title.should.containEql('WD');
        return done(err);
      });
    });
    it('submit element should be clicked', function(done) {
      return browser.namedSteps({
        submit: function(next) {
          return browser.clickElementById('submit', next);
        },
        checkUrl: function(next) {
          browser.getCurrentUrl(function(err, url) {});
          url.should.include('&submit');
          return next(err);
        }
      }, done);
    });
    return it('should click link and load new url', function(done) {
      return browser.namedSteps({
        clickLink: function(next) {
          return browser.clickElementById('i am a link', next);
        },
        waitForUrl: function(next) {
          return browser.waitForUrlToChange(/guinea-pig2/i, true, function(err, newUrl) {
            newUrl.should.not.equal(destinationUrl);
            return next(err);
          });
        }
      }, done);
    });
  });

}).call(this);
