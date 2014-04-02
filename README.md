Jeeves
======

Jeeves is a WebDriver abstraction built on top of [`wd`](https://github.com/admc/wd) which adds more logging and cleaner method naming conventions. Think of it as a [CasperJS](https://github.com/n1k0/casperjs)-like wrapper for driving automation across different browsers. Since it's built atop `wd`, it works seamlessly with [PhantomJS](http://phantomjs.org/), [Selenium JSON Wire Protocol](https://code.google.com/p/selenium/wiki/JsonWireProtocol), and [SauceLabs](https://saucelabs.com/).

## Initial features (v0.0.1)
  - Only supports using the promise chain version of `wd`
  - Depends on:
    + `async`
    + `lodash`
    + `ensureDir`
    + `jQuery` (client-side)

## Requirements/Setup
  - To use screenshots, a directory should be specified in the config otherwise by default they will save to `test-results/screenshots/`


## Todo
  - Need a way to accept config options
  - add examples
  - add more tests

## Contributing
Contributions in the form of pull requests and filing issues is welcomed & encouraged.
