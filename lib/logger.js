// Generated by CoffeeScript 1.9.3
(function() {
  var Logger, logLevelShims;

  Logger = (function() {
    function Logger() {}

    Logger.prototype.debug = typeof console !== "undefined" && console !== null ? console.log : void 0;

    Logger.prototype.test = typeof console !== "undefined" && console !== null ? console.log : void 0;

    Logger.prototype.log = typeof console !== "undefined" && console !== null ? console.log : void 0;

    Logger.prototype.error = typeof console !== "undefined" && console !== null ? console.error : void 0;

    Logger.prototype.warn = typeof console !== "undefined" && console !== null ? console.warn : void 0;

    return Logger;

  })();

  exports.logger = new Logger;

  logLevelShims = function(logger) {
    var i, len, levels, lvl;
    levels = ['debug', 'test', 'log', 'error', 'warn'];
    for (i = 0, len = levels.length; i < len; i++) {
      lvl = levels[i];
      switch (lvl) {
        case 'error':
          if (logger[lvl] == null) {
            logger[lvl] = typeof console !== "undefined" && console !== null ? console.error : void 0;
          }
          break;
        case 'warn':
          if (logger[lvl] == null) {
            logger[lvl] = typeof console !== "undefined" && console !== null ? console.warn : void 0;
          }
          break;
        default:
          if (logger[lvl] == null) {
            logger[lvl] = typeof console !== "undefined" && console !== null ? console.log : void 0;
          }
      }
    }
    return logger;
  };

  exports._shimLevels = logLevelShims;

}).call(this);
