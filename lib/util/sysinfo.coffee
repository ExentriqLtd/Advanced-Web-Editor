os = require 'os'
Configuration = require './configuration'
packageName = 'adv-web-editor'

gatherConfig = ->
  c = new Configuration()
  confData = c.get()
  ret =
    username: confData.username
    fullName: confData.fullName
  return ret

packageVersion = ->
  pkg = atom.packages.getLoadedPackage(packageName)
  return pkg.metadata.version

sysinfo =
  gatherInfo: ->
    data =
      module:
        name: packageName
        version: packageVersion()
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
