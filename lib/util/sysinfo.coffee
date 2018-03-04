os = require 'os'
Configuration = require './configuration'

gatherConfig = ->
  c = new Configuration()
  confData = c.get()
  ret =
    username: confData.username
    fullName: confData.fullName
  return ret

sysinfo =
  gatherInfo: ->
    data =
      os:
        type: os.type()
        arch: os.arch()
        platform: os.platform()
        release: os.release()
      loadavg: os.loadavg()
      userinfo: os.userInfo()
      config: gatherConfig()
    return data

module.exports = sysinfo
