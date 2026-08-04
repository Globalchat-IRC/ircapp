/// Nicks autorizados a ver/usar herramientas de IRCop y panel del staff.
/// NOTA: Esta es una lista de referencia en el cliente.
/// La autorización real debe validarse server-side.
/// Para modificar, editar esta lista o usar el endpoint de configuración del servidor.
Set<String> kAuthorizedStaffNicks = {
  'nan',
  'malthael',
  'fran',
  'izan',
};

/// Comandos de chat restringidos a personal autorizado (IRCop / servidor).
const Set<String> kIrcopRestrictedCommands = {
  'oper',
  'links',
  'stats',
  'trace',
  'map',
  'rehash',
  'kill',
  'gline',
  'kline',
  'zline',
  'shun',
  'sajoin',
  'sapart',
  'samode',
  'svsnick',
  'saprivmsg',
  'squit',
  'restart',
  'die',
  'connect',
};

bool isAuthorizedStaffNick(String? nick) {
  if (nick == null || nick.trim().isEmpty) return false;
  return kAuthorizedStaffNicks.contains(nick.trim().toLowerCase());
}

bool isIrcopRestrictedCommand(String command) {
  return kIrcopRestrictedCommands.contains(command.trim().toLowerCase());
}
