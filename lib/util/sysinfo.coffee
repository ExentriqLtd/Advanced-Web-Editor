os = require 'os'
Configuration = require './configuration'
packageInfo = require '../../package.json'

gatherConfig = ->
  c = new Configuration()
  confData = c.get()
  ret =
    username: confData.username
    fullName: confData.fullName
  return ret

sysinfo = () ->
  data =
    module:
      name: packageInfo.name
      version: packageInfo.version
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
