###
#  Jeeves
#  Selenium RemoteWebDriver abstraction layer using the 'wd' npm pkg
###

webdriver = require 'wd'
{asserters} = webdriver
async = require 'async'
_ = require 'lodash'
{logger, _shimLevels} = require './logger'


# in ms
SHORT_TIMEOUT = 8000
LONG_TIMEOUT = 16000
SHORT_INTERVAL = 200
LONG_INTERVAL = 500

# @todo: need clean way to choose either
#        CB-style, promise, or promise-chain depending which `wd` is used
#        Maybe not? if we just use promise-chain `wd` behind the scenes

module.exports = class Jeeves

  SPECIAL_KEYS: webdriver.SPECIAL_KEYS
  MOUSE_KEYS: 'left': 0, 'middle': 1, 'right': 2
  _utils:
    enableWdLogs: (driver) ->
      driver.on 'status', (info) -> logger.warn "wd_status << #{info}"

      driver.on 'command', (method, callPath, data) ->
        if not /CALL|RESPONSE/i.test method then return

        # special case - don't dump whole uploaded file
        if /\/file$/.test(callPath) and data?.file?
          data = JSON.stringify(data.file).substr(0, 50)+'...'
        # or screenshot :)
        if /takeScreenshot/.test callPath
          data = JSON.stringify(data)?.substr(0, 50)+'...'

        logger.debug "wd_cmd >> #{method} #{callPath} with data: #{data || 'NO_DATA'}"

  ###*
   * @param  {Object}  driver                 an instance of the wd.promiseChainRemote
   * @param  {Object}  options                configuration settings
   * @param  {String}  options.screenshotDir  Custom folder path where screenshots will be saved
   * @param  {Object}  options.logger         Custom logger
   * @param  {Boolean} options.wdLogging      Flag to enable wd's native logging.
   * @param  {Object}  options.wdConfig       Options to pass along to the wd. See https://github.com/admc/wd#named-parameters
   * @param  {Object}  options.wdCapabilities Options used to initialize the webdriver.
   *                                            See https://code.google.com/p/selenium/wiki/DesiredCapabilities
   * @return {undefined}
  ###
  constructor: (driver..., options = {}) ->
    wd_config = options.wdConfig ? {}
    @_wd_capabilites = options.wdCapabilities ? browserName:'chrome'

    @driver = driver.shift() ? null
    if not @driver? then @driver = new webdriver.promiseChainRemote wd_config

    if options.wdLogging then @_utils.enableWdLogs @driver

    webdriver.addAsyncMethod 'screenshot', (subdir, filename, cb) => @takeScreenshot subdir, filename, cb

    if options.logger? then logger = _shimLevels options.logger

    @_screenshotDir = options.screenshotDir ? "#{process.cwd()}/test-results/screenshots"

  init: (done) ->
    @driver.init @_wd_capabilites, (error, driverSessionId) =>
      if error
        logger.error "webdriver init error:", error.stack ? error
        return done error
      logger.test "webdriver created & initialized."
      logger.warn "webdriver sessionId:", driverSessionId
      done()

  ###
  #   Extension to `async.series`, run a named series flow (key:fn style)
  #   with optional `beforeEach()` & `afterEach()` callbacks,
  #   each being passed (name, fn).
  #   useful for logging async flows in tests.
  #   @todo: move to jeeves utils
  ###
  namedSteps: (tasks, doneCallback, beforeEach, afterEach) ->
    if _.isArray(tasks)
      throw new Error "asyncSeriesTap only works with a named stack"
    beforeEach ?= (fnName)-> logger.test "-- #{fnName}"

    for taskName, taskFn of tasks
      do (taskName, taskFn) ->
        tasks[taskName] = (next) ->
          beforeEach? taskName, taskFn

          # need to pass through error & any other params, so results still work
          taskFn (args...) ->
            afterEach? taskName, taskFn
            next.apply @, args

    async.series tasks, doneCallback


  #####################################
  #   Browser-level Utility Methods
  #####################################

  getBrowser: (done) ->
    logger.test '@getBrowser'
    @driver.getCurrentBrowser done

  explicitWait: (seconds, done) ->
    logger.test '@explicitWait', seconds
    setTimeout done, 1000 * seconds

  stopBrowser: (done) ->
    logger.test '@stopBrowser'
    clientScript = ->
      window.stop?()
      document.execCommand? "Stop", false
    @executeClientScript clientScript, (error) ->
      logger.error 'Stopping browser failed', error if error
      done()

  loadPage: (url, done) ->
    logger.test '@loadPage', url

    unless url?.length and !!url.toLowerCase().match(/^http/)
      return done new Error "Need full URL to loadPage, but got #{url}"

    logger.test 'Stopping browser before loading page.'
    @stopBrowser (error) =>
      if error
        error.message = "Error stopping browser: #{error.message}"
        return done error

      logger.test "Browser is stopped. Attempting to load url: #{url}"

      @driver
        .get(url)
        .nodeify (error) =>
          logger.test "Tried to load #{url}", error or 'no error'
          done error

  loadPageAndWait: (url, done)->
    logger.test '@loadPageAndWait', url
    @loadPage url, (error)=>
      if error
        logger.error "Error loading page: #{error.message ? error}"
        return done error
      # waiting for exact URL requested. so won't handle redirects.
      @waitForUrlToChange url, true, (error, actualUrl)=>
        logger.test '@loadPageAndWait got', (if error then "Error: #{error.message}" else actualUrl)
        done error, actualUrl

  getCurrentUrl: (done) ->
    logger.test '@getCurrentUrl'
    @driver
      .url()
      .nodeify (error, url) ->
        logger.test "-- current url is #{url}"
        done error, url

  navBack: (done) ->
    logger.test '@navBack'
    @driver
      .back()
      .nodeify(done)

  navForward: (done) ->
    logger.test '@navForward'
    @driver
      .forward()
      .nodeify(done)

  refreshPage: (done) ->
    logger.test '@refreshPage'
    @driver
      .refresh()
      .nodeify(done)

  getAllCookies: (done) ->
    logger.test '@getAllCookies'
    @driver
      .allCookies()
      .nodeify (error, cookies) ->
        logger.test "All cookies obtained(#{error ? 'no error'}):", cookies
        done error, cookies

  setCookie: (cookie, done) ->
    logger.test '@setCookie'
    @driver
      .setCookie(cookie)
      .nodeify (error) ->
        logger.test "Cookie set. #{error ? 'no error'}"
        done error

  deleteAllCookies: (done) ->
    logger.test '@deleteAllCookies'
    @driver
      .deleteAllCookies()
      .nodeify (error) ->
        logger.test "All cookies deleted! #{error ? 'no error'}"
        done error

  deleteCookie: (cookieName, done) ->
    logger.test '@deleteCookie'
    @driver
      .deleteCookie(cookieName)
      .nodeify (error) ->
        logger.test "Cookie deleted! #{error ? 'no error'}"
        done error

  getPageTitle: (done) ->
    logger.test '@getPageTitle'
    @driver
      .title()
      .nodeify (error, title) ->
        logger.test 'title obtained:', title
        done error, title

  getWindowHandles: (done) ->
    logger.test '@getWindowHandles'
    @driver
      .windowHandles()
      .nodeify(done)

  getCurrentWindowHandle: (done) ->
    logger.test '@getCurrentWindowHandle'
    @driver
      .windowHandle()
      .nodeify(done)

  switchToWindow: (windowName, done) ->
    logger.test "@switchToWindow named: #{windowName}"
    @driver
      .window(windowName)
      .nodeify(done)

  ###
  #  JS alert box management
  ###
  acceptAlert: (done) ->
    logger.test '@acceptAlert'
    @driver
      .acceptAlert()
      .nodeify(done)

  dismissAlert: (done) ->
    logger.test '@dismissAlert'
    @driver
      .dismissAlert()
      .nodeify(done)

  getAlertText: (done) ->
    logger.test '@getAlertText'
    @driver
      .alertText()
      .nodeify(done)

  sendAlertKeys: (keys, done) ->
    logger.test "@sendAlertKeys #{keys}"
    @driver
      .alertKeys(keys)
      .nodeify(done)

  # Quit the browser and end the webdriver session
  quit: (done) ->
    logger.test '@quit'
    @driver
      .quit()
      .nodeify(done)

  ###
  # @done callback gets (error, source)
  ###
  getFullBody: (done) ->
    logger.test '@getFullBody'
    @driver
      .source()
      .nodeify(done)

  # Take a screenshot, save it to a subdir of `@_screenshotDir`
  takeScreenshot: (subdir, filename, done) ->
    logger.test '@takeScreenshot'
    @driver
      .takeScreenshot()
      .nodeify (error, imgBuffer) =>
        if error then return done error

        ensureDir = require 'ensureDir'
        fs = require 'fs'
        directory = "#{@_screenshotDir}/#{subdir}"
        filePath = "#{directory}/#{filename}.png"

        ensureDir directory, '0755', (error) ->
          if error then return done error
          fs.writeFile filePath, imgBuffer, 'base64', (error) ->
            if error then done error
            else
              logger.test "Saved screenshot to #{filePath}"
              done null, filePath

  ###
  #  *SYNCHRONOUSLY* run a script on the client.
  #  @fn function to run in client scope.
  #    - fn should take same params as `params` here.
  #  @params... vars to pass to client scope.
  #  @done callback. gets results.
  #
  #  IMPT:
  #  - if `params` includes a hash w/ an inline function,
  #    the fn will be passed as a string, not a function (so it won't work).
  #  - return something short & simple! (coffeescript returns the last line,
  #    if it's something huge it'll overload the callstack)
  ###
  executeClientScript: (fn, params..., done) ->
    logger.test '@executeClientScript'
    @driver.execute fn, params, (error, results) =>
      logger.debug "@executeClientScript results: #{JSON.stringify results}\n"
      if error then done error
      # treat returned 'error' string as an error.
      else if _.isString(results) and /^error/i.test(results) then done new Error results
      else done null, results

  ###
  #  *ASYNCHRONOUSLY* run a script on the client.
  #  same as executeClientScript, but `fn` needs to include a callback
  #  and code execution will continue
  #    - order: fn(params..., callback)
  ###
  executeAsyncClientScript: (fn, params..., done) ->
    logger.test '@executeAsyncClientScript'
    @driver.executeAsync fn, params, (error, results) =>
      logger.debug "@executeAsyncClientScript results: #{JSON.stringify results}\n"
      if error then done error
      # treat returned 'error' string as an error.
      else if _.isString(results) and /^error/i.test(results) then done new Error results
      else done null, results

  # Webdriver Element Comparison
  compareElements: (elem1, elem2, done) ->
    logger.test '@compareElements'
    @driver
      .equalsElement(elem1, elem2)
      .nodeify(done)

  #####################################
  #   /Browser-level Utility Methods
  #####################################


  #####################################
  #   Interaction Methods
  #####################################

  phantomUploadFile: (selector, filePath, done) ->
    logger.test "@phantomUploadFile using: #{selector}\nFile: #{filePath}"
    if @driver.phantomUploadFile?
      @driver
        .phantomUploadFile(selector, filePath)
        .nodeify(done)
    else done new Error 'Phantom file uploads are not supported by your version of WD.'

  uploadFile: (filePath, done) ->
    logger.test "@uploadFile #{filePath}"
    @driver
      .uploadFile(filePath)
      .nodeify(done)

  jsMouseClick: (cssSelector, button..., done) ->
    # Buttons: 'left', 'middle', 'right'
    key = button.shift() or 'left'
    b = @MOUSE_KEYS[key]
    logger.test "@jsMouseClick with button: #{key}"
    jqueryClick = ->
      return $(arguments[0])[0].click()
    @executeClientScript jqueryClick, cssSelector, done

  mouseClick: (button..., done) ->
    # Buttons: 'left', 'middle', 'right'
    key = button.shift() or 'left'
    b = @MOUSE_KEYS[key]
    logger.test "@mouseClick with button: #{key}"
    @driver
      .click(b)
      .nodeify(done)

  mouseDownUp: (button..., done) ->
    # Buttons: 'left', 'middle', 'right'
    key = button.shift() or 'left'
    b = @MOUSE_KEYS[key]
    logger.test "@mouseDownUp with button: #{key}"
    @driver
      .buttonDown(b)
      .buttonUp(b)
      .nodeify(done)

  mouseMove: (x, y, done) ->
    logger.test "@mouseMove to x:#{x}, y:#{y}"
    @driver
      .moveTo(null, x, y)
      .nodeify(done)

  clearElement: (elem, done) ->
    logger.test '@clearElement', elem
    elem
      .clear?()
      .nodeify(done)

  clickElement: (elem, done) =>
    logger.test '@clickElement', elem
    elem
      .click?()
      .nodeify(done)

  typeKeys: (keys, done) ->
    logger.test '@typeKeys', keys
    @driver
      .keys(keys)
      .nodeify(done)

  forceElementVisible: (cssSelector, done) ->
    logger.test "@forceElementVisible #{cssSelector}"
    clientMakeVisible = (cssPath) ->
      $(cssPath).show()
      els = $(cssPath)
      for el in els
        el.style.visibility = 'visible'
        el.style.height = '1px'
        el.style.width = '1px'
        el.style.opacity = 1
      return
    @executeClientScript clientMakeVisible, cssSelector, done

  #####################################
  #   /Interaction Methods
  #####################################


  #####################################
  #   Check Methods
  #####################################

  hasClass: (elem, className, done)->
    logger.test "@hasClass(#{elem}, #{className})"
    elem
      .getAttribute('class')
      .nodeify (error, value) ->
        if error then return done error
        classes = value.split(' ')
        logger.test "** classNames on #{elem}: #{classes}"
        if className in classes
          logger.warn 'elem has class!'
          return done null, true
        done null, false

  isChecked: (elem, done) ->
    logger.test '@isChecked'
    @getAttributeValue elem, 'checked', done

  isSelected: (elem, done) ->
    logger.test '@isSelected'
    elem
      .isSelected?()
      .nodeify(done)

  isDisplayed: (elem, done) ->
    logger.test '@isDisplayed'
    elem
      .isDisplayed?()
      .nodeify(done)

  isTextPresent: (elem, searchText, done) ->
    logger.test "@isTextPresent {elem: #{elem}, searchText: #{searchText}}"
    elem
      .textPresent?(searchText)
      .nodeify (error, textFound) ->
        logger.test "Text found: #{textFound}"
        done error, textFound

  checkForElemWithProperText: (elemCssPath, elemText, done) ->
    logger.test "@checkForElemWithProperText params:{elemCssPath: #{elemCssPath}, elemText: #{elemText}}"
    elem = null
    @namedSteps
      getElementByCss: (next) =>
        @findElementOrNullByCss elemCssPath, (error, _elem) =>
          elem = _elem
          next error
      checkForElement: (next) =>
        next null, elem?
      checkForTextByCss: (next) =>
        unless elem?
          logger.test 'Element did not exist. Can\'t check for text.'
          next()
        else
          @isTextPresent elem, elemText, next
    , (error, results) ->
      logger.test '@checkForElemWithProperText results:', results
      _result = (results?.checkForElement and results?.checkForTextByCss)
      if _result? then done null, _result
      else done error, _result

  #####################################
  #   /Check Methods
  #####################################


  #####################################
  #   Getter Methods
  #####################################

  getActiveElement: (done) ->
    logger.test '@getActiveElement'
    @driver
      .active()
      .nodeify(done)

  getAttributeValue: (elem, attrName, done) ->
    logger.test "@getAttributeValue #{attrName}"
    elem
      .getAttribute?(attrName)
      .nodeify(done)

  getElementLocation: (elem, done) ->
    logger.test '@getElementLocation'
    elem
      .getLocation?()
      .nodeify(done)

  getComputedCss: (elem, cssProperty, done) ->
    logger.test '@getComputedCss'
    elem
      .getComputedCss?(cssProperty)
      .nodeify(done)

  getTagName: (elem, done) ->
    logger.test '@getTagName'
    elem
      .getTagName?()
      .nodeify(done)

  getText: (elem, done) ->
    logger.test '@getText on elem'
    elem
      .text?()
      .nodeify(done)

  getInnerHtmlByCss: (cssSelector, done) ->
    logger.test "@getInnerHtmlByCss on #{cssSelector}"
    clientInnerHtml = ->
      return $(arguments[0])[0].innerHTML
    @executeClientScript clientInnerHtml, cssSelector, done

  getCssCount: (cssSelector, done) ->
    logger.test '@getCssCount'
    async.waterfall [
      (next) =>
        @getElementsByCss cssSelector, next
      (elems, next) =>
        next null, elems.length
    ], (error, count) ->
      logger.test "Count is: #{count}"
      done error, count

  getTextOfElementsByCss: (cssSelector, done) ->
    logger.test "@getTextOfElementsByCss #{cssSelector}"
    clientGetTextFromElems = (cssPath) ->
      innards = []
      $(cssPath).each (i, el) -> innards.push $(el).text()
      return innards
    @executeClientScript clientGetTextFromElems, cssSelector, done

  #####################################
  #   /Getter Methods
  #####################################


  #####################################
  #   Wait Methods
  #####################################

  ###
  #  Generic `waitFor` method, can be used to wait for:
  #     test conditions or browser conditions
  #  wait for a `checkFn` callback to return true.
  #
  #  @checkFn(): should return (null,true) when passes.
  #    - can return error on error. null,false is ignored.
  #  @options
  #    @interval default 100ms.
  #    @timeout total time to wait. default 3 seconds.
  #    @msg message on timeout error
  ###
  waitForSomething: (checkFn, options, done) ->
    logger.test '@waitForSomething'
    _.defaults options,
      interval: 500
      timeout: 3000
      msg: '[something]'

    _finished = false
    checkCount = 0

    finish = _.once (error, result)->
      _finished = true
      clearTimeout finishTimeout
      logger.test "@waitForSomething finished after #{checkCount} checks. Took #{Date.now() - startTime}ms"
      if error then done error
      else done()

    finishTimeout = setTimeout ->
      finish new Error "Timed out after #{options.timeout}ms (#{checkCount} checks): #{options.msg}"
    , options.timeout

    startTime = Date.now()
    async.whilst ->
      _finished is false

    , (doneCheck)->
      # do a check. ends immediately on success or error.
      # on failure, waits til at least interval to end / check again.

      checkCount++
      doneCheck = _.once doneCheck

      intervalHasPassed = false
      checkIsDone = false

      # note when interval has passed,
      # and end if check is done.
      setTimeout ->
        intervalHasPassed = true
        if checkIsDone
          doneCheck()
      , options.interval

      checkFn (error, result)->
        checkIsDone = true

        if error or result is true
          finish error, result

          # end flow immediately
          doneCheck()
        else
          # if check took longer than interval
          if intervalHasPassed
            doneCheck()
          # (otherwise timeout runs)

    , -> #(already ended by `finish`)

  ###
  #  @expectedUrl string or regex
  #  @matches - should it match or not
  #  @options - options object for custom timeout & interval
  #  @done callback, gets (error, url).
  ###
  waitForUrlToChange: (expectedUrl, matches = true, options..., done) ->
    toFrom = if matches then 'to' else 'from'
    logger.test "@waitForUrlToChange #{toFrom} #{expectedUrl}"

    options = options.shift() or {}
    _.defaults options,
      timeout: LONG_TIMEOUT
      interval: SHORT_INTERVAL

    checkUrl = (callback) =>
      @getCurrentUrl (error, newUrl) ->
        if error then return callback error
        if _.isString(expectedUrl)    # string
          check = (newUrl is expectedUrl) is matches
        else                          # regex
          check = (!!newUrl.match expectedUrl) is matches
        callback null, check

    @waitForSomething checkUrl,
      msg: "URL did not change  #{toFrom} #{expectedUrl}"
      timeout: options.timeout
      interval: options.interval

    , (error) =>
      logger.test '-- waitForUrlToChange done. Attempting to get url', [ expectedUrl, error?.message ? 'no error' ]
      if error then return done error
      # pass back the new URL
      @getCurrentUrl done


  ###
  # wait for an element to have an attribute
  # @cssSelector the path to the element
  # @attr the attribute that you're expecting the evelope to have
  # @attrValue [optional] set if your waiting for the attribute to have a specific value
  # @done callback gets the el. (no reason to run 2nd call to get it when we know it exists.)
  ###
  waitForAttributeByCss: (cssSelector, attr, attrValue, done) ->
    logger.test "@waitForAttributeByCss {cssSelector: #{cssSelector}\nattr: #{attr}\nattrValue: #{attrValue}}"
    elemAttributeValue = null

    @waitForSomething (callback) =>
      @getAttributeValueByCss cssSelector, attr, (error, val) ->
        if error then return callback error
        else
          return callback null, false unless val?
          return callback null, false if attrValue? and val isnt attrValue
          elemAttributeValue = val
          callback null, true
    ,
      msg: "'#{attr}' -- not found"
      timeout: SHORT_TIMEOUT
      interval: LONG_INTERVAL
    , (error) ->
      if error then return done error
      logger.test "element '#{cssSelector}' has attribute #{attr} with value #{elemAttributeValue}"
      done null, elemAttributeValue

  ###
  # this method has benefit when waiting for text that isn't visible
  ###
  waitForInnerHtmlByCss: (selectorValue, regex, options..., done) =>
    logger.test "@waitForInnerHtmlByCss using { selectorValue: #{selectorValue}\n regex: #{regex} }"
    done = _.once done
    options = options.shift() or {}
    _.defaults options,
      timeout: 10000
      interval: 100
    htmlToReturn = null

    @waitForElementByCss selectorValue, options, (error) =>
      if error then return done error

      @waitForSomething (callback) =>
        @getInnerHtmlByCss selectorValue, (error, html) ->
          logger.test '    html is: ' + (html ? '[empty]')
          if error then return callback error
          htmlToReturn = html
          unless html then return callback null, false
          else callback null, (!!html.match regex)
      ,
        msg: "'#{regex}' -- not found. Last html found: #{htmlToReturn}"
        timeout: options.timeout
        interval: options.interval
      , (error) ->
        logger.test "done waiting for regex to match #{error ? 'no error'}"
        if error then return done error
        done null, htmlToReturn

  ### waitForCondition expected params
  # @conditionExpr: condition expression, should return a boolean
  # @timeout: timeout (optional, default: 5 sec)
  # @pollFreq: polling frequency (optional, default: 300ms)
  ###

  # Waits for condition to be true (polling within wd client)
  waitForCondition: (conditionExpr, timeout = 5, pollFreq = 300, done) ->
    logger.test '@waitForCondition'
    timeout = timeout * 1000
    condtion = asserters.jsCondition conditionExpr, true
    @driver
      .waitFor(condtion, timeout, pollFreq)
      .nodeify(done)

  # Waits for condition to be true (async script polling within browser)
  waitForConditionInBrowser: (conditionExpr, timeout = 5, pollFreq = 300, done) ->
    logger.test '@waitForConditionInBrowser'
    timeout = timeout * 1000
    @driver
      .waitForConditionInBrowser(conditionExpr, timeout, pollFreq)
      .nodeify(done)

  #####################################
  #   /Wait Methods
  #####################################


  #####################################
  #   Misc Action Methods
  #####################################

  ###
  # NOTE: this method is working but needs tests
  # @startElement - Element to move
  # @endpointPosition - takes in an object with x/y attributes - for example: {x: 20, y: 230}
  # @endpointElement - wd's documentation says this is optional, but that's not true
  #                   it actually bases the endpointPosition off the position of this element
  ###
  dragElement: (startElement, endpointPosition, endpointElement, done) ->
    logger.test "@dragElement ", endpointPosition
    @driver
      .moveTo(startElement, undefined, undefined)
      .buttonDown(0)
      .moveTo(endpointElement, 205, -5)
      .moveTo(endpointElement, endpointPosition.x, endpointPosition.y)
      .buttonUp(0)
      .nodeify(done) # same as: `.then( -> done() )`

  ###
  # Similar to `dragElement`, but simulates a mouse click to select then another to drop
  ###
  clickAndStamp: (startElement, endpointPosition, endpointElement, done) ->
    logger.test "@clickAndStamp ", endpointPosition
    @driver
      .moveTo(startElement, undefined, undefined)
      # .screenshot('clickAndStamp', "#{startElement}-before-click")
      .click(0)
      # .buttonDown(0)
      # .buttonUp(0)
      # .screenshot("clickAndStamp-#{startElement}", 'after-click_before-move')
      .moveTo(endpointElement, 205, -5)
      .moveTo(endpointElement, endpointPosition.x, endpointPosition.y)
      # .screenshot("clickAndStamp-#{startElement}", 'after-move_before-stamp')
      .click(0)
      # .buttonDown(0)
      # .screenshot('clickAndStamp', "#{startElement}-after-stamp")
      .nodeify(done) # same as: `.then( -> done() )`

  ieClickAndStamp: (startElement, endpointPosition, endpointElement, done) ->
    # @todo: ....ugh ie. The below link will give some brave soul a place to start :D :heart:
    #       https://code.google.com/p/selenium/issues/detail?id=4403#c14

  # Doesn't work and is very fragile. Needs tests
  # Leaving this to maybe fix later.
  ieDragAndDrop: (startElement, endpointPosition, endpointElement, done) ->
    logger.test "@ieDragAndDrop ", endpointPosition
    elemPos = pageX = pageY = elemId = null
    endPos = _.defaults endpointPosition
    @namedSteps
      endElemPost: (next) =>
        @getElementLocation endpointElement, (error, pos) ->
          endPos.x = endPos.x + pos.x
          endPos.y = endPos.y + pos.y
          next error
      elemPosition: (next) =>
        @getElementLocation startElement, (error, pos) ->
          elemPos = pos
          next error
      elemSize: (next) =>
        startElement.getSize().nodeify (error, elemSize) ->
          pageX = elemPos.x + ~~(elemSize.width / 2)
          pageY = elemPos.y + ~~(elemSize.height / 2)
          next error
      elemId: (next) =>
        @getAttributeValue startElement, 'id', (error, _elemId) =>
          elemId = _elemId
          next error
      jsSimulation: (next) =>
        # yup this is specific to martini, needs a refactor
        className = 'title'
        wtfIe = "var mousedown=document.createEvent(\"MouseEvent\"),mouseup=document.createEvent(\"MouseEvent\"),elem=document.getElementById(\"#{elemId}\"),result=[],elems=elem.getElementsByTagName(\"*\"),k=0,j=0,i,interval;for(i in elems){if((\" \"+elems[i].className+\" \").indexOf(\" #{className} \")>-1){result.push(elems[i]);}}mousedown.initMouseEvent(\"mousedown\",true,true,window,0,0,0,#{pageX},#{pageY},0,0,0,0,0,null);result[0].dispatchEvent(mousedown);interval=setInterval(function(){if(k!==#{endPos.x}){k++;};if(j!==#{endPos.y}){j++;};iter(k,j);if(k===#{endPos.x}+1&&j===#{endPos.y}+1){clearInterval(interval);mouseup.initMouseEvent(\"mouseup\",true,true,window,0,#{pageX}+k,#{pageY}+j,#{pageX}+k,#{pageY}+j,0,0,0,0,0,null);result[0].dispatchEvent(mouseup);}},100);function iter(_x,_y){var mousemove=document.createEvent(\"MouseEvent\");mousemove.initMouseEvent(\"mousemove\",true,true,window,0,0,0,#{pageX}+_x,#{pageY}+_y,0,0,0,0,0,null);result[0].dispatchEvent(mousemove);}"
        @driver.safeExecute wtfIe, next
    , done

  #####################################
  #   /Misc Action Methods
  #####################################


############################################################################
##
## Element Suffixed Methods
## e.g. do__X__ByCss , do__X__ById, etc... functions
##

Jeeves::_utils._elementFuncTypes = _elementFuncTypes = ['class name','css selector','id','name','link text','partial link text','tag name','xpath','css']

# convert to type to something like ById, ByCssSelector, etc...
Jeeves::_utils._elFuncSuffix = _elFuncSuffix = (type) ->
  res = (" by " + type).replace /(\s[a-z])/g, ($1)-> $1.toUpperCase().replace " ", ""
  res.replace "Xpath", "XPath"

_.each _elementFuncTypes, (type)->

  #####################################
  #   Find Methods
  #####################################

  ###
  # Single Find
  #   @getElementByClassName = (selectorValue, done) -> done(error, elem)
  #   @getElementByCssSelector = (selectorValue, done) -> done(error, elem)
  #   @getElementById = (selectorValue, done) -> done(error, elem)
  #   @getElementByName = (selectorValue, done) -> done(error, elem)
  #   @getElementByLinkText = (selectorValue, done) -> done(error, elem)
  #   @getElementByPartialLinkText = (selectorValue, done) -> done(error, elem)
  #   @getElementByTagName = (selectorValue, done) -> done(error, elem)
  #   @getElementByXPath = (selectorValue, done) -> done(error, elem)
  #   @getElementByCss = (selectorValue, done) -> done(error, elem)
  ###
  Jeeves::['getElement' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@getElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @driver["element#{_elFuncSuffix type}"](selectorValue)
      .nodeify (error, elem) ->
        logger.test "got the elem: #{elem}"
        done error, elem

  ###
  # Find single Elem IfExists
  #   @getElemIfExistsByClassName = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByCssSelector = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsById = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByName = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByLinkText = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByPartialLinkText = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByTagName = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByXPath = (selectorValue, done) -> done(error, elemOrUndefined)
  #   @getElemIfExistsByCss = (selectorValue, done) -> done(error, elemOrUndefined)
  ###
  Jeeves::['getElemIfExists' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@#{"element#{_elFuncSuffix type}IfExists"} using selectorValue: #{selectorValue}"
    @driver["element#{_elFuncSuffix type}IfExists"](selectorValue)
      .nodeify (error, elem) ->
        logger.test "got the elem: #{elem}"
        done error, elem

  ###
  # Multi Find
  #   @getElementsByClassName = (selectorValue, done) -> done(error, elems)
  #   @getElementsByCssSelector = (selectorValue, done) -> done(error, elems)
  #   @getElementsById = (selectorValue, done) -> done(error, elems)
  #   @getElementsByName = (selectorValue, done) -> done(error, elems)
  #   @getElementsByLinkText = (selectorValue, done) -> done(error, elems)
  #   @getElementsByPartialLinkText = (selectorValue, done) -> done(error, elems)
  #   @getElementsByTagName = (selectorValue, done) -> done(error, elems)
  #   @getElementsByXPath = (selectorValue, done) -> done(error, elems)
  #   @getElementsByCss = (selectorValue, done) -> done(error, elems)
  ###
  Jeeves::['getElements' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@getElements#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @driver["elements#{_elFuncSuffix type}"](selectorValue)
      .nodeify (error, elems) ->
        logger.test "got the elems: #{elems}"
        done error, elems

  ###
  # Find ElemOrNull
  #   @findElementOrNullByClassName = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByCssSelector = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullById = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByName = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByLinkText = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByPartialLinkText = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByTagName = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByXPath = (selectorValue, done) -> done(error, elemOrNull)
  #   @findElementOrNullByCss = (selectorValue, done) -> done(error, elemOrNull)
  ###
  Jeeves::['findElementOrNull' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@findElementOrNull#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @driver["element#{_elFuncSuffix type}OrNull"](selectorValue)
      .nodeify (error, elem) ->
        logger.test "got the elem?: #{elem}"
        done error, elem

  ###
  #   @getChildElementByClassName = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByCssSelector = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementById = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByName = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByLinkText = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByPartialLinkText = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByTagName = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByXPath = (elem, selectorValue, done) -> done(error, elem)
  #   @getChildElementByCss = (elem, selectorValue, done) -> done(error, elem)
  ###
  Jeeves::['getChildElement' + _elFuncSuffix type] = (elem, selectorValue, done) ->
    logger.test "@getChildElement#{_elFuncSuffix type} in parent #{elem?.value} using selector '#{selectorValue}'"
    elem["element#{_elFuncSuffix type}"](selectorValue)
      .nodeify (error, elem) ->
        logger.test "got the child elem: #{elem}"
        done error, elem

  ###
  #   @getChildElementsByClassName = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByCssSelector = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsById = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByName = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByLinkText = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByPartialLinkText = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByTagName = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByXPath = (elem, selectorValue, done) -> done(error, elems)
  #   @getChildElementsByCss = (elem, selectorValue, done) -> done(error, elems)
  ###
  Jeeves::['getChildElements' + _elFuncSuffix type] = (elem, selectorValue, done) ->
    logger.test "@getChildElements#{_elFuncSuffix type} in parent #{elem?.value} using selector '#{selectorValue}'"
    elem["elements#{_elFuncSuffix type}"](selectorValue)
      .nodeify (error, elems) ->
        logger.test "got the elems: #{elems}"
        done error, elems

  #####################################
  #   /Find Methods
  #####################################


  #####################################
  #   Interaction Methods
  #####################################

  ###
  #   @clickElementByClassName = (selectorValue, done) -> done(error)
  #   @clickElementByCssSelector = (selectorValue, done) -> done(error)
  #   @clickElementById = (selectorValue, done) -> done(error)
  #   @clickElementByName = (selectorValue, done) -> done(error)
  #   @clickElementByLinkText = (selectorValue, done) -> done(error)
  #   @clickElementByPartialLinkText = (selectorValue, done) -> done(error)
  #   @clickElementByTagName = (selectorValue, done) -> done(error)
  #   @clickElementByXPath = (selectorValue, done) -> done(error)
  #   @clickElementByCss = (selectorValue, done) -> done(error)
  ###
  Jeeves::['clickElement' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@clickElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to click...'
      elem
        .click()
        .nodeify(done)

  ###
  #   @submitByClassName = (selectorValue, done) -> done(error)
  #   @submitByCssSelector = (selectorValue, done) -> done(error)
  #   @submitById = (selectorValue, done) -> done(error)
  #   @submitByName = (selectorValue, done) -> done(error)
  #   @submitByLinkText = (selectorValue, done) -> done(error)
  #   @submitByPartialLinkText = (selectorValue, done) -> done(error)
  #   @submitByTagName = (selectorValue, done) -> done(error)
  #   @submitByXPath = (selectorValue, done) -> done(error)
  #   @submitByCss = (selectorValue, done) -> done(error)
  ###
  Jeeves::['submit' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@submit#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to submit form...'
      elem
        .submit()
        .nodeify(done)

  ###
  #   @sendTextToElementByClassName = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByCssSelector = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementById = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByName = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByLinkText = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByPartialLinkText = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByTagName = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByXPath = (selectorValue, text, done) -> done(error)
  #   @sendTextToElementByCss = (selectorValue, text, done) -> done(error)
  ###
  Jeeves::['sendTextToElement' + _elFuncSuffix type] = (selectorValue, text, done) ->
    logger.test "@sendTextToElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test "Element found! Attempting to type: #{text}"
      elem
        .sendKeys(text)
        .nodeify(done)

  ###
  #   @clearAndSendTextByClassName = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByCssSelector = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextById = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByName = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByLinkText = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByPartialLinkText = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByTagName = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByXPath = (selectorValue, text, done) -> done(error)
  #   @clearAndSendTextByCss = (selectorValue, text, done) -> done(error)
  ###
  Jeeves::['clearAndSendText' + _elFuncSuffix type] = (selectorValue, text, done) ->
    logger.test "@clearAndSendText#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to clear...'
      elem
        .clear()
        .then ->
          logger.test "Element cleared! Attempting to type: #{text}"
        .type(text)
        .nodeify(done)

  ###
  # Move to element, x and y offsets are optional.
  #   @mouseToElementByClassName = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByCssSelector = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementById = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByName = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByLinkText = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByPartialLinkText = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByTagName = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByXPath = (selectorValue, xOffset, yOffset, done) -> done(error)
  #   @mouseToElementByCss = (selectorValue, xOffset, yOffset, done) -> done(error)
  ###
  Jeeves::['mouseToElement' + _elFuncSuffix type] = (selectorValue, xOffset = 0, yOffset = 0, done) ->
    logger.test "@mouseToElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test "Element found! Attempting to move mouse to element...offset( x: #{xOffset}, y: #{yOffset} )"
      elem
        .moveTo(xOffset, yOffset)
        .nodeify(done)

  ###
  # Double-clicks current mouse using on elem found w/ selectorValue
  #   @doubleClickElementByClassName = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByCssSelector = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementById = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByName = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByLinkText = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByPartialLinkText = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByTagName = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByXPath = (selectorValue, offsets..., done) -> done(error)
  #   @doubleClickElementByCss = (selectorValue, offsets..., done) -> done(error)
  ###
  Jeeves::['doubleClickElement' + _elFuncSuffix type] = (selectorValue, offsets..., done) ->
    logger.test "@doubleClickElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    xOffset = offsets.shift() ? 0
    yOffset = offsets.shift() ? 0
    @["mouseToElement#{_elFuncSuffix type}"] selectorValue, xOffset, yOffset, (error) =>
      if error then return done error
      logger.test 'Mouse in position! Attempting to double-click...'
      @driver
        .doubleclick()
        .nodeify(done)

  ###
  # Send mouseDown then mouseUp to elem found w/ selectorValue
  #   @mouseDownUpByClassName = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByCssSelector = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpById = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByName = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByLinkText = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByPartialLinkText = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByTagName = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByXPath = (selectorValue, offsets..., done) -> done(error)
  #   @mouseDownUpByCss = (selectorValue, offsets..., done) -> done(error)
  ###
  Jeeves::['mouseDownUp' + _elFuncSuffix type] = (selectorValue, offsets..., done) ->
    logger.test "@mouseDownUp#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    xOffset = offsets.shift() ? 0
    yOffset = offsets.shift() ? 0
    @["mouseToElement#{_elFuncSuffix type}"] selectorValue, xOffset, yOffset, (error, elem) =>
      if error then return done error
      logger.test 'Mouse in position! Attempting to mouseDown then mouseUp using left mouse button...'
      @driver
        .buttonDown(0)
        .buttonUp(0)
        .nodeify(done)

  ###
  #   @mouseClickByClassName = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByCssSelector = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickById = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByName = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByLinkText = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByPartialLinkText = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByTagName = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByXPath = (selectorValue, offsets..., done) -> done(error)
  #   @mouseClickByCss = (selectorValue, offsets..., done) -> done(error)
  ###
  Jeeves::['mouseClick' + _elFuncSuffix type] = (selectorValue, offsets..., done) ->
    logger.test "@mouseClick#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    xOffset = offsets.shift() ? 0
    yOffset = offsets.shift() ? 0
    @["mouseToElement#{_elFuncSuffix type}"] selectorValue, xOffset, yOffset, (error, elem) =>
      if error then return done error
      logger.test 'Mouse in position! Attempting to click using left mouse button...'
      @driver
        .click(0)
        .nodeify(done)

  #####################################
  #   /Interaction Methods
  #####################################


  #####################################
  #   Check Methods
  #####################################

  ###
  #   @isSelectedByClassName = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByCssSelector = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedById = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByName = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByLinkText = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByPartialLinkText = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByTagName = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByXPath = (selectorValue, done) -> done(error, boolean)
  #   @isSelectedByCss = (selectorValue, done) -> done(error, boolean)
  ###
  Jeeves::['isSelected' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@isSelected#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to check if selected...'
      elem
        .isSelected()
        .nodeify (error, selected) ->
          if not error
            logger.test("isSelected result: #{selected}")
          done error, selected

  ###
  #   @isEnabledByClassName = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByCssSelector = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledById = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByName = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByLinkText = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByPartialLinkText = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByTagName = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByXPath = (selectorValue, done) -> done(error, boolean)
  #   @isEnabledByCss = (selectorValue, done) -> done(error, boolean)
  ###
  Jeeves::['isEnabled' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@isEnabled#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to check if enabled...'
      elem
        .isEnabled()
        .nodeify (error, enabled) ->
          if not error
            logger.test("isEnabled result: #{enabled}")
          done error, enabled

  ###
  #   @isDisplayedByClassName = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByCssSelector = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedById = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByName = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByLinkText = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByPartialLinkText = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByTagName = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByXPath = (selectorValue, done) -> done(error, boolean)
  #   @isDisplayedByCss = (selectorValue, done) -> done(error, boolean)
  ###
  Jeeves::['isDisplayed' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@isDisplayed#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if not elem and error?.message.match /Error response status: 7/
        # the element doesn't exist, therefor it must not be displayed - so this shouldn't be an error
        logger.test 'Element not found'
        return done null, false
      else if error then return done error
      logger.test 'Element found! Attempting to check if displayed...'
      elem
        .isDisplayed()
        .nodeify (error, displayed) ->
          if not error
            logger.test("isDisplayed result: #{displayed}")
          done error, displayed

  ###
  #   @isTextPresentByClassName = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByCssSelector = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentById = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByName = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByLinkText = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByPartialLinkText = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByTagName = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByXPath = (selectorValue, searchText, done) -> done(error, boolean)
  #   @isTextPresentByCss = (selectorValue, searchText, done) -> done(error, boolean)
  ###
  Jeeves::['isTextPresent' + _elFuncSuffix type] = (selectorValue, searchText, done) ->
    logger.test "@isTextPresent#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test "Element found! Attempting to check for text: #{searchText}"
      elem
        .textPresent(searchText)
        .nodeify (error, textFound) ->
          if not error
            logger.test("Text found: #{textFound}")
          done error, textFound

  ###
  #   @checkForElementByClassName = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByCssSelector = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementById = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByName = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByLinkText = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByPartialLinkText = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByTagName = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByXPath = (selectorValue, done) -> done(error, boolean)
  #   @checkForElementByCss = (selectorValue, done) -> done(error, boolean)
  ###
  Jeeves::['checkForElement' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@checkForElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @driver["hasElement#{_elFuncSuffix type}"](selectorValue)
      .nodeify (error, exists) =>
        logger.test "@checkForElement#{_elFuncSuffix type} result: #{exists}"
        done error, exists

  #####################################
  #   /Check Methods
  #####################################


  #####################################
  #   Getter Methods
  #####################################

  ###
  #   @getTextByClassName = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByCssSelector = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextById = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByName = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByLinkText = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByPartialLinkText = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByTagName = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByXPath = (selectorValue, opts..., done) -> done(error, text)
  #   @getTextByCss = (selectorValue, opts..., done) -> done(error, text)
  ###
  Jeeves::['getText' + _elFuncSuffix type] = (selectorValue, opts..., done) ->
    logger.test "@getText#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    callCount = opts.shift() or 1
    # @todo: @ask: @review: is this error check still needed since it uses promises now?
    if callCount > 2
      return done new Error 'getText() is in a loop of Error response status: 10'
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) =>
      if error then return done error
      logger.test 'Element found! Attempting to get text...'
      elem
        .text()
        .nodeify (error, innerText) =>
          if error?.message.match /Error response status: 10/
            @["getText#{_elFuncSuffix type}"] selectorValue, callCount+1, done
          else done error, innerText

  ###
  #   @getAttributeValueByClassName = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByCssSelector = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueById = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByName = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByLinkText = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByPartialLinkText = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByTagName = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByXPath = (selectorValue, attrName, done) -> done(error, attrValue)
  #   @getAttributeValueByCss = (selectorValue, attrName, done) -> done(error, attrValue)
  ###
  Jeeves::['getAttributeValue' + _elFuncSuffix type] = (selectorValue, attrName, done) ->
    logger.test "@getAttributeValue#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test "Element found! Attempting to get attribute(#{attrName})..."
      elem
        .getAttribute(attrName)
        .nodeify (error, attrVal) ->
          if not error
            logger.test "got attribute value: #{attrVal}"
          done error, attrVal

  ###
  #   @getComputedCssPropByClassName = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByCssSelector = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropById = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByName = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByLinkText = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByPartialLinkText = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByTagName = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByXPath = (selectorValue, cssProp, done) -> done(error, computedCss)
  #   @getComputedCssPropByCss = (selectorValue, cssProp, done) -> done(error, computedCss)
  ###
  Jeeves::['getComputedCssProp' + _elFuncSuffix type] = (selectorValue, cssProp, done) ->
    logger.test "@getComputedCssProp#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test "Element found! Attempting to get computed css prop(#{cssProp})..."
      elem
        .getComputedCss(cssProp)
        .nodeify (error, cssPropVal) ->
          if not error
            logger.test("got computed css property: #{cssPropVal}")
          done error, cssPropVal

  ###
  #   @getSizeByClassName = (value, done) -> done(error, elemSize)
  #   @getSizeByCssSelector = (value, done) -> done(error, elemSize)
  #   @getSizeById = (value, done) -> done(error, elemSize)
  #   @getSizeByName = (value, done) -> done(error, elemSize)
  #   @getSizeByLinkText = (value, done) -> done(error, elemSize)
  #   @getSizeByPartialLinkText = (value, done) -> done(error, elemSize)
  #   @getSizeByTagName = (value, done) -> done(error, elemSize)
  #   @getSizeByXPath = (value, done) -> done(error, elemSize)
  #   @getSizeByCss = (value, done) -> done(error, elemSize)
  ###
  Jeeves::['getSize' + _elFuncSuffix type] = (value, done) ->
    logger.test "@getSize#{_elFuncSuffix type} using #{value}"
    @["getElement#{_elFuncSuffix type}"] value, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to get elem size...'
      elem
        .getSize()
        .nodeify (error, elemSize) ->
          if not error
            logger.test("got elem size: #{elemSize}")
          done error, elemSize

  ###
  #   @getElemLocationByClassName = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByCssSelector = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationById = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByName = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByLinkText = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByPartialLinkText = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByTagName = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByXPath = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationByCss = (selectorValue, done) -> done(error, elemLocation)
  ###
  Jeeves::['getElemLocation' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@getElemLocation#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to get location...'
      elem
        .getLocation()
        .nodeify (error, elemLoc) ->
          if not error
            logger.test('got elem location: ', elemLoc)
          done error, elemLoc

  ###
  #   @getElemLocationInViewByClassName = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByCssSelector = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewById = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByName = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByLinkText = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByPartialLinkText = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByTagName = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByXPath = (selectorValue, done) -> done(error, elemLocation)
  #   @getElemLocationInViewByCss = (selectorValue, done) -> done(error, elemLocation)
  ###
  Jeeves::['getElemLocationInView' + _elFuncSuffix type] = (selectorValue, done) ->
    logger.test "@getElemLocationInView#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    @["getElement#{_elFuncSuffix type}"] selectorValue, (error, elem) ->
      if error then return done error
      logger.test 'Element found! Attempting to get location in view...'
      elem
        .getLocationInView()
        .nodeify (error, elemLoc) ->
          if not error
            logger.test('got elem location in view: ', elemLoc)
          done error, elemLoc

  #####################################
  #   /Getter Methods
  #####################################


  #####################################
  #   Wait For Methods
  #####################################

  ###
  #   @waitForElementByClassName = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByCssSelector = (selectorValue, options..., done) -> done(error)
  #   @waitForElementById = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByName = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByPartialLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByTagName = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByXPath = (selectorValue, options..., done) -> done(error)
  #   @waitForElementByCss = (selectorValue, options..., done) -> done(error)
  ###
  Jeeves::['waitForElement' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @driver["waitForElement#{_elFuncSuffix type}"](selectorValue, timeout, SHORT_INTERVAL)
      .nodeify (error) ->
        if not error
          logger.test('Waiting complete! Element exists on page')
        done error

  ###
  #   @waitForVisibleElementByClassName = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByCssSelector = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementById = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByName = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByPartialLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByTagName = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByXPath = (selectorValue, options..., done) -> done(error)
  #   @waitForVisibleElementByCss = (selectorValue, options..., done) -> done(error)
  ###
  Jeeves::['waitForVisibleElement' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForVisibleElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @driver["waitForElement#{_elFuncSuffix type}"](selectorValue, asserters.isDisplayed, timeout, interval)
      .nodeify (error) ->
        if not error
          logger.test('Waiting complete! Element is visible')
        done error

  ###
  #   @waitForElementToHideByClassName = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByCssSelector = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideById = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByName = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByPartialLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByTagName = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByXPath = (selectorValue, options..., done) -> done(error)
  #   @waitForElementToHideByCss = (selectorValue, options..., done) -> done(error)
  ###
  Jeeves::['waitForElementToHide' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForElementToHide#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @driver["waitForElement#{_elFuncSuffix type}"](selectorValue, asserters.isNotDisplayed, timeout, interval)
      .nodeify (error) ->
        if not error
          logger.test('Waiting complete! Element is hidden')
        done error

  ###
  #   @waitForAndGetElementByClassName = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByCssSelector = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementById = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByName = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByLinkText = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByPartialLinkText = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByTagName = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByXPath = (selectorValue, options..., done) -> done(error, elem)
  #   @waitForAndGetElementByCss = (selectorValue, options..., done) -> done(error, elem)
  ###
  Jeeves::['waitForAndGetElement' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForAndGetElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval, visibleElem} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    if visibleElem is true then waitForMethod = "waitForVisibleElement#{_elFuncSuffix type}"
    else waitForMethod = "waitForElement#{_elFuncSuffix type}"
    @[waitForMethod] selectorValue, {timeout, interval}, (error) =>
      if error then return done error
      if not error
        logger.test('Waiting complete! Attempting to get & return element...')
      @["getElement#{_elFuncSuffix type}"] selectorValue, done

  ###
  #   @waitForAndGetElementsByClassName = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByCssSelector = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsById = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByName = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByLinkText = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByPartialLinkText = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByTagName = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByXPath = (selectorValue, options..., done) -> done(error, elems)
  #   @waitForAndGetElementsByCss = (selectorValue, options..., done) -> done(error, elems)
  ###
  Jeeves::['waitForAndGetElements' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForAndGetElements#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @driver["waitForElement#{_elFuncSuffix type}"](selectorValue, timeout, interval)
      .nodeify (error) =>
        if error then return done error
        if not error
          logger.test('Waiting complete! Attempting to get & return element...')
        @["getElements#{_elFuncSuffix type}"] selectorValue, done

  ###
  #   @waitForTextByClassName = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByCssSelector = (selectorValue, options..., done) -> done(error)
  #   @waitForTextById = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByName = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByPartialLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByTagName = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByXPath = (selectorValue, options..., done) -> done(error)
  #   @waitForTextByCss = (selectorValue, options..., done) -> done(error)
  ###
  Jeeves::['waitForText' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForText#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @driver["waitForElement#{_elFuncSuffix type}"](selectorValue, asserters.nonEmptyText, timeout, interval)
      .nodeify (error) ->
        if not error
          logger.test('Waiting complete, element text is not empty.')
        done error

  ###
  #   @waitForElementTextByClassName = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByCssSelector = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextById = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByName = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByLinkText = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByPartialLinkText = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByTagName = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByXPath = (selectorValue, text, options..., done) -> done(error, boolean)
  #   @waitForElementTextByCss = (selectorValue, text, options..., done) -> done(error, boolean)
  ###
  Jeeves::['waitForElementText' + _elFuncSuffix type] = (selectorValue, text, options..., done) ->
    logger.test "@waitForElementText#{_elFuncSuffix type} using selectorValue: #{selectorValue}, expected text: #{text}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @driver["waitForElement#{_elFuncSuffix type}"](selectorValue, asserters.textInclude(text), timeout, interval)
      .nodeify (error) ->
        if not error
          logger.test("Waiting complete, element text is #{text}")
        done error

  ###
  #   @waitForAndGetTextByClassName = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByCssSelector = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextById = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByName = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByLinkText = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByPartialLinkText = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByTagName = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByXPath = (selectorValue, options..., done) -> done(error, text)
  #   @waitForAndGetTextByCss = (selectorValue, options..., done) -> done(error, text)
  ###
  Jeeves::['waitForAndGetText' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForAndGetText#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @["waitForAndGetElement#{_elFuncSuffix type}"] selectorValue, {timeout, interval}, (error, elem) =>
      if error then return done error
      logger.test 'Element found! Attempting to get text...'
      elem
        .text()
        .nodeify (error, text) =>
          logger.test "Got text? => #{text}"
          done error, text

  ###
  #   @waitForAndClickElementByClassName = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByCssSelector = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementById = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByName = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByPartialLinkText = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByTagName = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByXPath = (selectorValue, options..., done) -> done(error)
  #   @waitForAndClickElementByCss = (selectorValue, options..., done) -> done(error)
  ###
  Jeeves::['waitForAndClickElement' + _elFuncSuffix type] = (selectorValue, options..., done) ->
    logger.test "@waitForAndClickElement#{_elFuncSuffix type} using selectorValue: #{selectorValue}"
    options = options.shift() or {}
    {timeout, interval} = options
    timeout = timeout ? SHORT_TIMEOUT
    interval = interval ? SHORT_INTERVAL
    @["waitForAndGetElement#{_elFuncSuffix type}"] selectorValue, {timeout, interval, visibleElem:true}, (error, elem) =>
      if error then return done error
      logger.test 'Element found! Attempting to click...'
      elem
        .click()
        .nodeify(done)

  #####################################
  #   /Wait For Methods
  #####################################
