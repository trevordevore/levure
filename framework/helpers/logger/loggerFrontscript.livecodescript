script "Logger FrontScript"
# LCB
on logChanged pMsg
  _loggerLogChanged pMsg
  if not the result then pass logChanged
end logChanged


# libURL
on ulLogIt pMsg
  _loggeruLogIt pMsg
  if not the result then pass ulLogIt
end ulLogIt


# Message Box
on msgChanged
  _loggerMsgChanged
  if not the result then pass msgChanged
end msgChanged
