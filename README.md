Jeeves
======

Jeeves is a callback-style WebDriver abstraction built atop of [`wd`](https://github.com/admc/wd). By default it includes detailed logging to aid in the debugging of functional UI testing, and friendly method name conventions. Think of it as a [CasperJS](https://github.com/n1k0/casperjs)-like wrapper for powering UI automation across different browsers. Since its core functionality is built using `wd`, it works seamlessly with [PhantomJS](http://phantomjs.org/), [Selenium JSON Wire Protocol](https://code.google.com/p/selenium/wiki/JsonWireProtocol), and [SauceLabs](https://saucelabs.com/).

## Install
```
npm install jeeves
```



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
