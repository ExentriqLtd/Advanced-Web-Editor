{app} = require 'remote'
CSON = require('cson')
path = require 'path'

{File, Directory} = require 'atom'
FILE_PATH = path.join(app.getPath("userData"), "adv-web-editor.cson")

class Configuration
  @labels:
    repoUrl: "Project Clone URL"
    fullName: "Full Name"
    email: "Your Email",
    repoOwner: "Repository Owner"
    username: "Username for Branches"
    repoUsername: "Repository User Name"
    password: "Password"
    cloneDir: "Clone Directory"
    advancedMode: "Advanced Mode"

  @reasons:
    repoUrl: "Project Clone URL must be a valid http://, https:// or SSH Git repository"
    fullName: "Full Name must not be empty"
    email: "Your Email must be a valid email address",
    repoOwner: "Repository Owner must not be empty. It is required for pull requests."
    username: "Username for Branches must not be empty. It is required to identify your branches."
    repoUsername: "Repository User Name must not be empty. It is required by BitBucket API."
    password: "Password must not be empty. It is required for pull requests."
    cloneDir: "Clone Directory must be set"
    advancedMode: "Advanced Mode"

  @validators:
    isValidRepo: (value) ->
      return Configuration.validators.isNotBlank(value) &&
        (Configuration.validators.isValidHttp(value) || Configuration.validators.isValidSsh(value))

    isNotBlank: (value) ->
      return value?.trim?().length > 0

    whatever: (value) ->
      return true

    isValidHttp: (value) ->
      return value.startsWith("http")

    isValidSsh: (value) ->
      return !value.startsWith("http") && value.indexOf '@' >= 0

    isEmail: (value) ->
      re = /^(([^<>()\[\]\\.,;:\s@"]+(\.[^<>()\[\]\\.,;:\s@"]+)*)|(".+"))@((\[[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}])|(([a-zA-Z\-0-9]+\.)+[a-zA-Z]{2,}))$/
      return re.test(value)

  @validationRules:
    repoUrl: @validators.isValidRepo
    fullName: @validators.isNotBlank
    email: @validators.isEmail
    repoOwner: @validators.isNotBlank
    username: @validators.isNotBlank
    repoUsername: @validators.isNotBlank
    password: @validators.isNotBlank
    cloneDir: @validators.isNotBlank
    advancedMode: @validators.whatever

  constructor: () ->
    @read()

  exists: () ->
    return @confFile.existsSync()

  read: () ->
    console.log "AdvancedWebEditor::read", FILE_PATH
    @confFile = new File(FILE_PATH)
    if @exists()
      try
        @conf = CSON.parseCSONFile(FILE_PATH)
        # console.log "Read configuration: ", @conf
      catch error
        console.warn "Invalid configuration detected"
        @conf = null
    else
      @confFile.create()
      @conf = null
      return @conf

  get: () ->
    if !@conf
      @conf = {}
    # console.log "configuration::get", @conf
    return @conf

  set: (c) ->
    @conf = c
    # console.log "configuration::set", @conf
    return this

  isHttp: ()->
    return @conf.repoUrl.startsWith("http")

  save: () ->
    console.log "AdvancedWebEditor::save", FILE_PATH
    s = CSON.stringify(@conf)
    #@confFile.create().then =>
    @confFile.writeSync(s)
    # console.log "configuration::save", @conf

  isValid: () ->
    allKeys = @conf && Object.keys(@conf).filter (k) ->
      keys.find (j) ->
        k == j
    .length == keys.length
    return allKeys && @validateAll().length == 0

  validateAll: () ->
    return Object.keys(Configuration.validationRules).map (rule) =>
      res = Configuration.validationRules[rule](@conf[rule])
      return if res then null else rule
    .filter (x) -> x

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

keys = Object.keys(Configuration.labels)
module.exports = Configuration
