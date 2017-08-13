{app} = require 'remote'
CSON = require('cson')

{File, Directory} = require 'atom'
FILE_PATH = app.getPath("userData") + "/" + "adv-web-editor.cson"
keys = ["repoUrl", "username", "password", "cloneDir"]
GitUtils = require './git-utils'

module.exports = class Configuration

  constructor: () ->
    @read()

  exists: () ->
    return @confFile.existsSync()

  read: () ->
    console.log "AdvancedWebEditor::read", FILE_PATH
    @confFile = new File(FILE_PATH)
    if @exists()
      @conf = CSON.parseFile(FILE_PATH)
      console.log @conf
    else
      @conf = null

  get: () ->
    if !@conf
      @conf = {}
    return @conf

  isHttp: ()->
    return @conf.repoUrl.startsWith("http")

  save: () ->
    console.log "AdvancedWebEditor::save", FILE_PATH
    s = CSON.stringify(@conf)
    @confFile.create().then =>
      @confFile.write(s)

  isValid: () ->
    return @conf && Object.keys(@conf).filter((k) ->
      keys.find((j) ->
        k == j))
    .length == keys.length

  isStringEmpty: (s) ->
    return !(s && s.trim && s.trim().length > 0)

  assembleCloneUrl: () ->
    if(!@isHttp)
      return @conf.repoUrl

    if @isStringEmpty(@conf.username)
      return @conf.repoUrl
    i = @conf.repoUrl.indexOf("//")
    if i < 0
      return @conf.repoUrl
    return @conf.repoUrl.substring(0, i + 2) + @conf.username + ":" + @conf.password + "@" + @conf.repoUrl.substring(i+2)

  cloneDirExists: () ->
    gu = new GitUtils()
    return !@isStringEmpty(@conf.cloneDir) && new Directory(@conf.cloneDir + "/" + gu.get_repo_name(@conf.repoUrl)).existsSync()
