module.exports = class GuineaPageObject

  constructor: (@driverWrapper) ->

  title: (done) ->
    @driverWrapper.getPageTitle done

  submitForm: (done) ->
    @driverWrapper.clickElementById 'submit', done

  clickLink: (done) ->
    @driverWrapper.clickElementById 'i am a link', done
