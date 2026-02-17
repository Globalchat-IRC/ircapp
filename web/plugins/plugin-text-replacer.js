/**
 * Plugin Text Replacer - Portado de mlite2.
 * Reemplaza el mensaje genérico "Error de inicio de sesión" por uno más amigable
 * si aparece en el DOM (p. ej. desde un gateway o ASL).
 * No depende de Kiwi; funciona en irc_app web.
 */
(function() {
  var from = 'Error de inicio de sesión. Vuelve a intentarlo o ponte en contacto con el servicio de ayuda';
  var to = '❌ Error de autenticación: Contraseña incorrecta o nick no válido. Verifica tus datos e intenta de nuevo.';
  function replaceInNode(node) {
    if (node.nodeType === Node.TEXT_NODE && node.textContent && node.textContent.indexOf('Error de inicio de sesión') !== -1) {
      node.textContent = node.textContent.replace(from, to);
      return true;
    }
    if (node.nodeType === Node.ELEMENT_NODE && node.textContent && node.textContent.indexOf('Error de inicio de sesión') !== -1) {
      node.textContent = node.textContent.replace(from, to);
      return true;
    }
    return false;
  }
  function walk() {
    var walker = document.createTreeWalker(document.body, NodeFilter.SHOW_TEXT, null, false);
    var node;
    while ((node = walker.nextNode())) {
      if (node.textContent && node.textContent.indexOf('Error de inicio de sesión') !== -1) {
        node.textContent = node.textContent.replace(from, to);
      }
    }
  }
  var observer = new MutationObserver(function() {
    setTimeout(walk, 100);
  });
  if (document.body) {
    walk();
    observer.observe(document.body, { childList: true, subtree: true, characterData: true });
  } else {
    document.addEventListener('DOMContentLoaded', function() {
      walk();
      observer.observe(document.body, { childList: true, subtree: true, characterData: true });
    });
  }
  if (typeof window.ircApp !== 'undefined') {
    window.ircApp.pluginsLoaded = window.ircApp.pluginsLoaded || [];
    window.ircApp.pluginsLoaded.push('text-replacer');
  }
})();
