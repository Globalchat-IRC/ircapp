/**
 * Plugin Hide Console - Portado de mlite2.
 * Silencia console.log/info/warn en producción (opcional).
 * No depende de Kiwi; funciona en irc_app web.
 */
(function() {
  if (typeof window.ircApp !== 'undefined') {
    window.ircApp.pluginsLoaded = window.ircApp.pluginsLoaded || [];
    window.ircApp.pluginsLoaded.push('hide-console');
  }
  var noop = function() {};
  var origError = console.error;
  console.log = noop;
  console.info = noop;
  console.warn = noop;
  console.error = function() {
    var a = arguments;
    if (a[0] && typeof a[0] === 'string' && (a[0].indexOf('ERROR') !== -1 || a[0].indexOf('FATAL') !== -1 || a[0].indexOf('CRITICAL') !== -1)) {
      origError.apply(console, a);
    }
  };
})();
