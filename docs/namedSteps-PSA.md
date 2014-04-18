##Today's PSA is brought to you by the Lawn Gnomes Association of the Trans-Atlantic Coast

### PSA: Help your fellow QA in debugging

Writing tests, then following the flow of events in the console output to debug can be a pain sometimes. Luckily [Jeeves](https://github.com/DocuSignDev/Jeeves), our handy web driver abstraction, provides a nice wrapper for [`async.series`](https://github.com/caolan/async#series) that by default will output some logging before each step to help you keep track of the data flow. This method is available as `Jeeves.namedSteps`, or `@myDriver.namedSteps` if you're within the context of a test file.

Below I will cover the method's API in detail, and then show a simple example of it. The interface for this method is similar to `async.series` except in the the type of the `tasks` argument, and the number of callback arguments it allows.

**NOTE:** The `namedSteps` method will only accept `tasks` that are objects composed of named keys with functions as the value of each key, or property.

The start of it's function definition looks like:
```coffeescript
Jeeves::namedSteps = (tasks, doneCallback, beforeEach, afterEach) ->
```
Contrast this with `async.series`:
```coffeescript
async.series = (tasks, callback) ->
```

Here we can see that `namedSteps` takes 2 additional parameters, both of which are optional. As you might imagine the `beforeEach` & `afterEach` parameters expect functions, and they shall be run directly before & after each step from `tasks`, respectively.

Though if you just want the helpful logging mentioned earlier you can simply pass the `doneCallback` and nothing else. This will make `beforeEach` default to the function below, where `fnName` will be the named property of the task about to run. There is no default function for `afterEach`.

```coffeescript
beforeEach = (fnName) -> logger.test "-- #{fnName}"
```

**NOTE:** Currently there is no way to pass arguments to the `beforeEach` & `afterEach` functions. Most use cases did not call for it, though I have ideas for refactoring it if you need this functionality.

Now that we've covered the API, let's see an example. Let's write a small test to check for and eat delicious baked goods from a cookie jar. We'll define both of the extra callbacks for better demonstration. We'll also assume that `cookieMonster` does not do any logging on it's own.

```coffeescript
it 'should check for fresh delicious cookies', (done) ->
  Jeeves.namedSteps
    openJar: (next) ->
      cookieMonster.openJar next
    checkForCookies: (next) ->
      cookieMonster.checkAnyCookies (error) ->
        if error then next error
        else next()
    eatCookies: (next) ->
      cookieMonster.eatAllCookies next
  , done
  , (fnName) ->
    console.log "-- before #{fnName}"
  , (fnName) ->
    console.log "~~ after #{fnName}"
```

Simple enough. What does this output in our console though?

```
> ․ should check for fresh delicious cookies
> -- before openJar
> ~~ after openJar
> -- before checkForCookies
> ~~ after checkForCookies
> -- before eatCookies
> ~~ after eatCookies
> ✓ should check for fresh delicious cookies
```

SUCCESS!!! ヘ(^_^ヘ)

So going forward I implore you to use `namedSteps` instead of `async.series` pretty much everywhere. If you not within the context of a test or don't have direct access to Jeeves, you can access the same function in Martini from `server/utils/utils.coffee`. Like so:
```coffeescript
{testSteps} = require basePath + '/server/utils/utils'
```
