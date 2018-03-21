os = require 'os'
packageInfo = require '../../package.json'

gatherConfig = (c) ->
  if c
    confData = c.get()
  else
    confData =
      username: null
      fullName: null

  ret =
    username: confData.username
    fullName: confData.fullName
  return ret

sysinfo = (configuration) ->
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
    config: gatherConfig(configuration)
    atom: atom.getVersion()
  return data

module.exports = sysinfo
