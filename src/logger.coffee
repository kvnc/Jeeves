class Logger
  debug  : console?.log
  test   : console?.log
  log    : console?.log
  error  : console?.error
  warn   : console?.warn

exports.logger = new Logger


logLevelShims = (logger) ->
  levels = [
    'debug'
    'test'
    'log'
    'error'
    'warn'
  ]
  for lvl in levels
    switch lvl
      when 'error'
        logger[lvl] ?= console?.error
      when 'warn'
        logger[lvl] ?= console?.warn
      else
        logger[lvl] ?= console?.log
  logger

exports._shimLevels = logLevelShims
