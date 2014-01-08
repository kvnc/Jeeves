###
#  Jeeves - wd Webdriver Wrapper
#  Selenium RemoteWebDriver abstraction layer using the 'wd' npm pkg
###
webdriver = require 'wd' # @todo: decouple from wd
winston = require 'winston' # @todo: make it logger agnostic
async = require 'async'
_ = require 'lodash'

###
  @todo: Clarify @myDriver / @driver in docs. Should always go through @myDriver
###

# @todo: Before open-sourcing, need clean way to choose
#        CB-style/Promise/PromiseChain webdriver

module.exports = class DriverWrapper

  SPECIAL_KEYS: webdriver.SPECIAL_KEYS

  constructor: (@driver, options) ->
    @screensRootDir = options.screensRootDir

    @_init()

  _init: ->
    ######################################
    ## Adding all do__X__ByCss... , do__X__ById... functions
    ######################################

    _.each @_elementFuncTypes, (type) =>

      ######################################
      ##    Find Methods
      ######################################

      # Single Find
      @['getElement' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@getElement#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @driver["element#{@_elFuncSuffix type}"](selectorValue)
          .nodeify (error, elem) ->
            winston.test "got the elem: #{elem}"
            done error, elem

      # Find single Elem IfExists
      @["element" + @_elFuncSuffix type + "IfExists"] = (selectorValue, done) =>
        winston.test "@#{"element#{@_elFuncSuffix type}IfExists"} using selectorValue: #{selectorValue}"
        @driver["element#{@_elFuncSuffix type}IfExists"](selectorValue)
          .nodeify (error, elem) ->
            winston.test "got the elem: #{elem}"
            done error, elem

      # Multi Find
      @["getElements" + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@getElements#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @driver["elements#{@_elFuncSuffix type}"](selectorValue)
          .nodeify (error, elems) ->
            winston.test "got the elems: #{elems}"
            done error, elems

      # Find ElemOrNull
      @["findEelementOrNull" + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@findElementOrNull#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @driver["element#{@_elFuncSuffix type}OrNull"](selectorValue)
          .nodeify (error, elem) ->
            winston.test "got the elem?: #{elem}"
            done error, elem

      ######################################
      ##    Interaction Methods
      ######################################

      @['clickElement' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@clickElement#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to click..."
          elem
            .click()
            .nodeify(done)

      @['submit' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@submit#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to submit form..."
          elem
            .submit()
            .nodeify(done)

      @['sendTextToElement' + @_elFuncSuffix type] = (selectorValue, text, done) =>
        winston.test "@sendTextToElement#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to type: #{text}"
          elem
            .sendKeys(text)
            .nodeify(done)

      @['clearAndSendText' + @_elFuncSuffix type] = (selectorValue, text, done) =>
        winston.test "@clearAndSendText#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to clear..."
          elem
            .clear()
            .then ->
              winston.test "Element cleared! Attempting to type: #{text}"
            .type(text)
            .nodeify(done)

      # Move to element, xoffset and y offset are optional.
      @['mouseToElement' + @_elFuncSuffix type] = (selectorValue, xOffset = 0, yOffset = 0, done) =>
        winston.test "@mouseToElement#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to move mouse to element...offset( x: #{xOffset}, y: #{yOffset} )"
          elem
            .moveTo(xOffset, yOffset)
            .nodeify(done)

      # Double-clicks at current mouse position using an elem found by selectorValue
      @['doubleClickElement' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@clickElement#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["mouseToElement#{@_elFuncSuffix type}"] selectorValue, (error) =>
          if error then return done error
          winston.test "Mouse in position! Attempting to double-click..."
          @driver
            .doubleclick()
            .nodeify(done)

      # Send mouseDown then mouseUp to wdElementObject found w/ selectorValue
      @['mouseDownUp' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@mouseDownUp#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["mouseToElement#{@_elFuncSuffix type}"] selectorValue, 0, 0, (error, elem) =>
          if error then return done error
          winston.test "Mouse in position! Attempting to mouseDown then mouseUp using left mouse button..."
          @driver
            .buttonDown(0)
            .buttonUp(0)
            .nodeify(done)

      @['mouseClick' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@mouseClick#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["mouseToElement#{@_elFuncSuffix type}"] selectorValue, 0, 0, (error, elem) =>
          if error then return done error
          winston.test "Mouse in position! Attempting to click using left mouse button..."
          @driver
            .click(0)
            .nodeify(done)

      ######################################
      ##    Check Methods
      ######################################

      @['isVisible' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@isVisible#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if not elem and error?.message.match /Error response status: 7/
            winston.test 'Element not found'
            return done null, false
          else if error then return done error
          winston.test "Element found! Attempting to check if visible..."
          elem
            .isVisible()
            .nodeify (error, visible) ->
              winston.test "isVisible result: #{visible}"
              done error, visible

      @['isSelected' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@isSelected#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to check if selected..."
          elem
            .isSelected()
            .nodeify (error, selected) ->
              winston.test "isSelected result: #{selected}"
              done error, selected

      @['isEnabled' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@isEnabled#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to check if enabled..."
          elem
            .isEnabled()
            .nodeify (error, enabled) ->
              winston.test "isEnabled result: #{enabled}"
              done error, enabled

      @['isDisplayed' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@isDisplayed#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if not elem and error?.message.match /Error response status: 7/
            winston.test 'Element not found'
            return done null, false
          else if error then return done error
          winston.test "Element found! Attempting to check if displayed..."
          elem
            .isDisplayed()
            .nodeify (error, displayed) ->
              winston.test "isDisplayed result: #{displayed}"
              done error, displayed

      @['isChecked' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@isChecked#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) =>
          if error then return done error
          winston.test "Element found! Attempting to check if checked..."
          @getAttributeValue elem, 'checked', (error, checked) ->
            winston.test "isChecked result: #{!!checked}"
            done error, !!checked

      @['isTextPresent' + @_elFuncSuffix type] = (selectorValue, searchText, done) =>
        winston.test "@isTextPresent#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to check for text: #{searchText}"
          elem
            .textPresent(searchText)
            .nodeify (error, textFound) ->
              winston.test "Text found: #{textFound}"
              done error, textFound

      # Sugar for Existence Checks
      @['checkForElement' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@checkForElement#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @driver["hasElement#{@_elFuncSuffix type}"](selectorValue)
          .nodeify (error, exists) =>
            winston.test "@checkForElement#{@_elFuncSuffix type} result: #{exists}"
            done error, exists

      ######################################
      ##    Getter Methods
      ######################################

      @['getText' + @_elFuncSuffix type] = (selectorValue, opts..., done) =>
        winston.test "@getText#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        callCount = opts.shift() or 1
        # @todo: Write tests for this to check if is this error check
        #        still needed
        if callCount > 2
          return done new Error "getText() is in a loop of Error response status: 10"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) =>
          if error then return done error
          winston.test "Element found! Attempting to get text..."
          elem
            .text()
            .nodeify (error, innerText) =>
              if error?.message.match /Error response status: 10/
                @["getText#{@_elFuncSuffix type}"] selectorValue, callCount+1, done
              else done error, innerText

      @['getAttributeValue' + @_elFuncSuffix type] = (selectorValue, attrName, done) =>
        winston.test "@getAttributeValue#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to get attribute(#{attrName})..."
          elem
            .getAttribute(attrName)
            .nodeify (error, attrVal) ->
              winston.test "got attribute value: #{attrVal}"
              done error, attrVal

      @['getComputedCssProp' + @_elFuncSuffix type] = (selectorValue, cssProp, done) =>
        winston.test "@getComputedCssProp#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to get computed css prop(#{cssProp})..."
          elem
            .getComputedCss(cssProp)
            .nodeify (error, cssPropVal) ->
              winston.test "got computed css property: #{cssPropVal}"
              done error, cssPropVal

      @['getSize' + @_elFuncSuffix type] = (value, done) =>
        winston.test "@getSize#{@_elFuncSuffix type} using #{value}"
        @["getElement#{@_elFuncSuffix type}"] value, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to get elem size..."
          elem
            .getSize()
            .nodeify (error, elemSize) ->
              winston.test "got elem size: #{elemSize}"
              done error, elemSize

      @['getElemLocation' + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@getElemLocation#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["getElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) ->
          if error then return done error
          winston.test "Element found! Attempting to get location..."
          elem
            .getElementLocation()
            .nodeify (error, elemLoc) ->
              winston.test "got elem location: #{elemLoc}"
              done error, elemLoc

      ######################################
      ##    Wait For Methods
      ######################################

      ###
      #  WaitFor__X__By...
      #  @timeout: default 5 sec
      ###
      @["waitForElement" + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@#{"waitForElement" + @_elFuncSuffix type} using selectorValue: #{selectorValue}"
        timeout = 5000
        @driver["waitForElement#{@_elFuncSuffix type}"](selectorValue, @driver.isVisible, timeout)
          .nodeify (error) ->
            winston.test "Waiting complete! Element is visible"
            done error

      @["waitForAndGetElement" + @_elFuncSuffix type] = (selectorValue, done) =>
        winston.test "@#{"waitForElement" + @_elFuncSuffix type} using selectorValue: #{selectorValue}"
        timeout = 5000
        @driver["waitForElement#{@_elFuncSuffix type}"](selectorValue, @driver.isVisible, timeout)
          .nodeify (error) =>
            winston.test "Waiting complete! Attempting to get & return element..."
            @["getElement#{@_elFuncSuffix type}"] selectorValue, done

      @['waitForText' + @_elFuncSuffix type] = (selectorValue, text, done) =>
        winston.test "@waitForText#{@_elFuncSuffix type} using selectorValue: #{selectorValue}"
        @["waitForAndGetElement#{@_elFuncSuffix type}"] selectorValue, (error, elem) =>
          if error then return callback error
          winston.test "Element found! Attempting to check text for #{text}..."
          elem
            .textPresent(text)
            .nodeify (error, present) =>
              winston.test "text present? => #{present}"
              done error, present


  ######################################
  ## Browser-level & Utility methods
  ######################################

  # convert to type to something like ById, ByCssSelector, etc...
  _elFuncSuffix: (type) ->
    res = (" by " + type).replace /(\s[a-z])/g, ($1) ->
      $1.toUpperCase().replace " ", ""
    res.replace "Xpath", "XPath"

  _elementFuncTypes: ['class name','css selector','id','name','link text','partial link text','tag name','xpath','css']

  getBrowser: (done) ->
    winston.test '@getBrowser'
    @driver.getCurrentBrowser done

  shortWait: (seconds, done) ->
    winston.test '@shortWait', seconds
    setTimeout done, 1000 * seconds

  stopBrowser: (done) ->
    winston.test '@stopBrowser'
    clientScript = ->
      window.stop.call @
    @executeClientScript clientScript, (error) =>
      winston.error 'Stopping browser failed', error if error
      done()

  loadPage: (url, done) ->
    winston.test '@loadPage', url

    unless url?.length and !!url.toLowerCase().match(/^http/)
      return done new Error "Need full URL to loadPage", url

    winston.test "Stopping browser before loading page."
    @stopBrowser (error) =>
      if error
        error.message = "Error stopping browser: #{error.message}"
        return done error
      @driver
        .get(url)
        .nodeify (error) =>
          winston.test "Loaded #{url}?", error or true
          done error

  getCurrentUrl: (done) ->
    winston.test '@getCurrentUrl'
    @driver
      .url()
      .nodeify (error, url) ->
        if error then return done error
        winston.test "-- current url is", url
        done null, url

  reloadPage: (done) ->
    winston.test '@reloadPage'
    @getCurrentUrl (error, url) =>
      if error then return done error
      # check if it says that it's still saving
      @getTextById 'status-global', (error, status) =>
        if error then return done error
        # should it force itself to wait using waitTillDoneSaving()?
        if status then winston.warn '    --- the app isnt done yet, but reloading page anyhow', status
        @loadPage url, done

  getPageTitle: (done) ->
    winston.test '@getPageTitle'
    @driver
      .title()
      .nodeify (error, title) ->
        winston.test 'title obtained:', title
        done error, title

  getWindowHandles: (done) ->
    winston.test "@getWindowHandles"
    @driver
      .windowHandles()
      .nodeify(done)

  getCurrentWindowHandle: (done) ->
    winston.test "@getCurrentWindowHandle"
    @driver
      .windowHandle()
      .nodeify(done)

  switchToWindow: (windowName, done) ->
    winston.test "@switchToWindow named:", windowName
    @driver
      .window(windowName)
      .nodeify(done)

  ###
  # Alert box management
  ###
  acceptAlert: (done) ->
    winston.test '@acceptAlert'
    @driver
      .acceptAlert()
      .nodeify(done)

  dismissAlert: (done) ->
    winston.test '@dismissAlert'
    @driver
      .dismissAlert()
      .nodeify(done)

  ###
  # Quit the browser
  ###
  quit: (done) ->
    @driver
      .quit()
      .nodeify(done)

  # Take a screenshot, save it to a subdir of ../screenshots
  # @todo: refactor this before open-sourcing driverWrapper
  takeScreenshot: (subdir, filename, done) ->
    winston.test '@takeScreenshot'
    @driver
      .takeScreenshot()
      .nodeify (error, imgBuffer) ->
        if error then return done error

        ensureDir = require 'ensureDir'
        fs = require 'fs'
        # @todo: expose this as passable options
        directory = @screensRootDir # conf.testResultsFolder + 'screenshots/' + subdir + '/'
        filePath = directory + filename + '.png'

        ensureDir directory, '0755', (error) ->
          fs.writeFile filePath, imgBuffer, 'base64', (error) ->
            if error then done error
            else
              winston.test "Saved screenshot to", filePath
              done null, filePath

  ###
  #  run a *SYNCHRONOUS* script on the client.
  #  @param fn function to run in client scope.
  #    - fn should take same params as `params` here.
  #  @param params... vars to pass to client scope.
  #  @param done callback. gets results.
  #
  #  IMPT:
  #  - if `params` includes a hash w/ an inline function,
  #    the fn will be passed as a string, not a function (so it won't work).
  #  - return something short & simple! (coffeescript returns the last line,
  #    if it's something huge it'll overload the callstack)
  ###
  executeClientScript: (fn, params..., done) ->
    winston.test "@executeClientScript"
    @driver.execute fn, params, (error, results) =>
      winston.debug "@executeClientScript results:", results, '\n'
      done error, results

  ###
  #  run an *ASYNCHRONOUS* script on the client.
  #  same as executeClientScript, but `fn` needs to include a callback.
  #    - order: fn(params..., callback)
  ###
  executeAsyncClientScript: (fn, params..., done) ->
    winston.test "@executeAsyncClientScript"
    @driver.executeAsync fn, params, (error, results) =>
      winston.debug "@executeAsyncClientScript results:", results
      done error, results

  ######################################
  ## ~~End Browser-level & Utility methods
  ######################################

  ######################################
  ## Misc Helper Methods
  ######################################

  ######################################
  ##    Interaction Methods
  ######################################

  clearElement: (elem, done) ->
    winston.test "@clearElement"
    elem
      .clear()
      .nodeify(done)

  clickElement: (elem, done) =>
    winston.test "@clickElement"
    elem
      .click()
      .nodeify(done)

  selectOptionFromDropdown: (dropdownElemCss, optionCssSelector, done) ->
    winston.test '@selectOptionFromDropdown', dropdownElemCss, optionCssSelector
    @mouseClickByCss dropdownElemCss, (error) =>
      if error then return done error
      @shortWait .5, (error) =>
        #screenshots seem to be the best way to do force the `select` to complete - add one before and after selecting
        @takeScreenshot 'dropdown', 'before', (error) =>
          @clickElementByCss optionCssSelector, (error) =>
            @takeScreenshot 'dropdown', 'later', (error) => done error

  typeKeys: (keys, done) ->
    winston.test '@typeKeys', keys
    @driver
      .keys(keys)
      .nodeify(done)

  makeButtonVisible: (cssSelector, done) ->
    winston.test '@makeButtonVisible', cssSelector
    clientMakeVisible = (cssPath) ->
      return $("#{cssPath}").show()
    @executeClientScript clientMakeVisible, cssSelector, done

  ######################################
  ##    Check Methods
  ######################################

  isChecked: (elem, done) ->
    winston.test '@isChecked'
    @getAttributeValue elem, 'checked', (error, checked) -> done error, checked

  isDisplayed: (elem, done) ->
    winston.test '@isDisplayed'
    elem
      .isDisplayed()
      .nodeify(done)

  isVisible: (elem, done) ->
    winston.test '@isVisible'
    elem
      .isVisible()
      .nodeify(done)

  checkForErrorByCss: (cssSelector, expectedErrorMsg, done) ->
    winston.test '@checkForErrorByCss', cssSelector
    @isTextPresentByCss cssSelector, expectedErrorMsg, done

  _pageHasProperElem: (elemCssPath, elemText, done) ->
    winston.test "@_pageHasProperElem params:{elemCssPath: #{elemCssPath}, elemText: #{elemText}}"
    async.series
      checkForElementByCss: (next) => @checkForElementByCss elemCssPath, next
      checkForTextByCss: (next) =>
        if elemText? then @isTextPresentByCss elemCssPath, elemText, next
        else next null, true
    , (error, results) ->
      winston.test "@_pageHasProperElem results:", results
      if results.checkForElementByCss and results.checkForTextByCss then done null, true
      else done error, false



  ######################################
  ##    Getter Methods
  ######################################

  getActiveElement: (done) ->
    winston.test "@getActiveElement"
    @driver
      .active()
      .nodeify(done)

  getAttributeValue: (elem, attrName, done) ->
    winston.test "@getAttributeValue", attrName
    elem
      .getAttribute(attrName)
      .nodeify(done)

  getElementLocation: (elem, done) ->
    winston.test "@getElementLocation"
    elem
      .getLocation()
      .nodeify(done)

  getComputedCss: (elem, cssProperty, done) ->
    winston.test "@getComputedCss"
    elem
      .getComputedCss(cssProperty)
      .nodeify(done)

  getTagName: (elem, done) ->
    winston.test "@getTagName"
    elem
      .getTagName()
      .nodeify(done)

  getText: (elem, done) ->
    winston.test "@getText on elem"
    elem
      .text()
      .nodeify(done)

  getInnerHtmlByCss: (cssSelector, done) ->
    winston.test "@getInnerHtmlByCss on ", cssSelector
    clientInnerHtml = ->
      return $( arguments[0] )[0].innerHTML
    @executeClientScript clientInnerHtml, cssSelector, done

  getAlertText: (done) ->
    winston.test "@getAlertText"
    @driver
      .getAlertText()
      .nodeify(done)

  getCssCount: (cssSelector, done) ->
    winston.test '@getCssCount'
    async.waterfall [
      (next) =>
        @getElementsByCss cssSelector, next
      (elems, next) =>
        next null, elems.length
    ], (error, count) ->
      winston.test "Count is: #{count}"
      done error, count

  getTextOfListByCss: (cssSelector, done) ->
    winston.test '@getTextOfListByCss', cssSelector
    @getElementsByCss cssSelector, (error, elems) =>
      if error then return done error
      async.reduce elems, [], (htmlList, elem, next) =>
        @getText elem, (error, elemHtml) ->
          if error
            if error.message.match /Element is no longer attached to the DOM/
              # This will catch the flakiness of getting text from an element that changes
              #   if you're actually checking the text, your test will still fail, but if all your test is concerned with
              #   is concerned with is the general list (or count) it won't fail due to page load delay
              htmlList.push ''
              return next null, htmlList
            else
              return done error
          htmlList.push elemHtml
          next null, htmlList
      , (error, results) => done error, results

  getOptionValuesByCss: (cssSelector, done) ->
    winston.test '@getOptionValuesByCss', cssSelector
    clientGetTextFromElems = (cssPath) ->
      innards = []
      $("#{cssPath}").each (i, el) -> innards.push $(el).text()
      return innards
    @executeClientScript clientGetTextFromElems, cssSelector, done

  ######################################
  ##    Element Comparison
  ######################################

  compareElements: (elem1, elem2, done) ->
    winston.test "@compareElements"
    @driver
      .equalsElement(elem1, elem2)
      .nodeify(done)

  ######################################
  ##    Wait Methods
  ######################################

  ###
  #  @param expectedUrl string or regex
  #  @param to - should it match or not
  #  @param done callback, gets (error, url).
  ###
  waitForUrlToChange: (expectedUrl, to = true, done) ->
    winston.test '@waitForUrlToChange ' + (if to then 'to' else 'from') + ' ' + expectedUrl

    checkUrl = (callback) =>
      @getCurrentUrl (error, newUrl) =>
        if error then return callback error
        if _.isString(expectedUrl)    # string
          check = (newUrl is expectedUrl) is to
        else                          # regex
          check = (!!newUrl.match expectedUrl) is to
        callback null, check

    @waitForSomething checkUrl,
      msg: "URL did not change  #{if to then 'to' else 'from'} #{expectedUrl}"
      timeout: 12500
      interval: 200

    , (error) =>
      winston.test "-- waitForUrlToChange done. Attempting to get url", [ expectedUrl, error?.message ? 'no error' ]
      if error then return done error
      # pass back the new URL
      @getCurrentUrl done


  ###
  # Wait for an element to have an attribute. attributeValue is returned
  # @cssSelector
  # @attr the attribute that you're expecting the evelope to have
  # @attrValue [optional] set if your waiting for the attribute to have a specific value
  # @done callback gets the el. (no reason to run 2nd call to get it when we know it exists.)
  ###
  waitForAttributeByCss: (cssSelector, attr, attrValue, done) ->
    winston.test '@waitForAttributeByCss', cssSelector, attr, attrValue
    elemAttributeValue = null

    @waitForSomething (callback) =>
      @getAttributeValueByCss cssSelector, attr, (error, val) =>
        if error then return callback error
        else
          return callback null, false unless val?
          return callback null, false if attrValue and val isnt attrValue
          elemAttributeValue = val
          callback null, true
    ,
      msg: "'#{attr}' -- not found"
      timeout: 5000
      interval: 500
    , (error) =>
      if error then return done error
      winston.test "element '#{cssSelector}' has attribute #{attr}", elemAttributeValue
      done null, elemAttributeValue


  ###
  #  Wait for multiple elements to exist.
  #    => @done(error, elemsFound)
  ###
  waitForElementsByCss: (cssSelector, done) ->
    winston.test '@waitForElementsByCss', cssSelector
    elemsFound = null

    @waitForSomething (callback) =>
      @getElementsByCss cssSelector, (error, elems) =>
        if error
          if error.name is 'NoSuchElementError'
            return callback null, false
          else
            return callback error
        else
          elemsFound = elems
          callback null, true
    ,
      msg: "'#{cssSelector}' -- not found"
      timeout: 5000
      interval: 500
    , (error) =>
      if error then return done error
      winston.test "element '#{cssSelector}' exists"
      done null, elemsFound


  # This method has benefit when waiting for text that isn't visible
  waitForInnerHtmlByCss: (selectorValue, regex, done) =>
    winston.test "@waitForInnerHtmlByCss using selectorValue: #{selectorValue}"
    done = _.once done
    @waitForSomething (callback) =>
      @getInnerHtmlByCss selectorValue, (error, html) =>
        if error then return callback error
        unless html then return callback null, false
        else callback null, (!!html.match regex)
    ,
      msg: "'#{regex}' -- not found"
      timeout: 10000
      interval: 100
    , (error) =>
      winston.test ' done waiting for regex to match'
      if error then return done error
      done null, true

  ### waitForCondition expected params
  # @conditionExpr: condition expression, should return a boolean
  # @timeout: timeout (optional, default: 5 sec)
  # @pollFreq: polling frequency (optional, default: 300ms)
  ###

  # Waits for condition to be true (polling within wd client)
  waitForCondition: (conditionExpr, timeout = 5, pollFreq = 300, done) ->
    winston.test "@waitForCondition"
    timeout = timeout * 1000
    @driver
      .waitForCondition(conditionExpr, timeout, pollFreq)
      .nodeify(done)

  # Waits for condition to be true (async script polling within browser)
  waitForConditionInBrowser: (conditionExpr, timeout = 5, pollFreq = 300, done) ->
    winston.test "@waitForConditionInBrowser"
    timeout = timeout * 1000
    @driver
      .waitForConditionInBrowser(conditionExpr, timeout, pollFreq)
      .nodeify(done)

  # @Note: `wdElementObject`s are returned by methods where it would be expected.
  #         Code according else file Pull Req :)
  ###
  # Simulates a mouse click and drag
  # @startElement wdElementObject - Element to move.  With most broswer drivers, the element is
  #                                 clicked from the center. I think.
  # @endpointPosition Object  - Object with x/y attributes - e.g.: {x: 20, y: 230}
  # @endpointElement wdElementObject - Element to end at.
  ###
  dragElement: (startElement, endpointPosition, endpointElement, done) ->
    winston.test '@dragElement', endpointPosition
    @driver
      .moveTo(startElement, undefined, undefined)
      .buttonDown(0)
      .moveTo(endpointElement, 205, -5)
      .moveTo(endpointElement, endpointPosition.x, endpointPosition.y)
      .buttonUp(0)
      .nodeify(done) # same as: `.then( -> done() )`

  clickAndStamp: (startElement, endpointPosition, endpointElement, done) ->
    winston.test '@clickAndStamp', endpointPosition
    @driver
      .moveTo(startElement, undefined, undefined)
      .buttonDown(0)
      .buttonUp(0)
      .moveTo(endpointElement, 205, -5)
      .moveTo(endpointElement, endpointPosition.x, endpointPosition.y)
      .buttonDown(0)
      .buttonUp(0)
      .nodeify(done) # same as: `.then( -> done() )`

  ###
  # => @done(error, sourceHtml)
  ###
  getFullBody: (done)->
    @driver
      .source()
      .nodeify(callback)
