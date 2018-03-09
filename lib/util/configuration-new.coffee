{app} = require 'remote'
CSON = require 'cson'
path = require 'path'
log = require './logger'

{File, Directory} = require 'atom'
FILE_PATH = path.join(app.getPath("userData"), "adv-web-editor.cson")
PREVIEW_CONF = path.join(app.getPath("userData"), "mapr-preview.cson")

getRepoName = (uri) ->
  tmp = uri.split('/')
  name = tmp[tmp.length-1]
  tmp = name.split('.')
  [..., last] = tmp
  if last is 'git'
    name = tmp[...-1].join('.')
  else
    name

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
    username: "Username for Branches must be made of just letters or numbers. It is required to identify your branches."
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

    isAlphaNum: (value) ->
      re = /^[\w]*$/
      return re.test(value)

  @validationRules:
    repoUrl: @validators.isValidRepo
    fullName: @validators.isNotBlank
    email: @validators.isEmail
    repoOwner: @validators.isNotBlank
    username: @validators.whatever # it is calculated
    repoUsername: @validators.isNotBlank
    password: @validators.isNotBlank
    cloneDir: @validators.isNotBlank
    advancedMode: @validators.whatever

  constructor: () ->
    @read()

  exists: () ->
    return @confFile.existsSync()

  read: () ->
    log.debug "AdvancedWebEditor::read", FILE_PATH
    @confFile = new File(FILE_PATH)
    if @exists()
      try
        @conf = CSON.parseCSONFile(FILE_PATH)
        # log.debug "Read configuration: ", @conf
      catch error
        log.warn "Invalid configuration detected"
        @conf = null
    else
      @confFile.create()
      @conf = null
      return @conf

  readPreviewConf: () ->
    result = null
    log.debug "AdvancedWebEditor::readPreviewConf", PREVIEW_CONF
    previewConf = new File(PREVIEW_CONF)
    if !previewConf.existsSync()
      log.debug "No MapR Preview configuration found"
    else
      try
        result = CSON.parseCSONFile(PREVIEW_CONF)
      catch error
        log.warn "Mapr Preview: Invalid configuration detected"

    if result
      # For uniformity
      result.repoUsername = result.username
      delete result.username

    log.debug "Mapr Preview Configuration", result
    return result

  get: () ->
    if !@conf
      @conf = {}
    # log.debug "configuration::get", @conf
    return @conf

  set: (c) ->
    @conf = c
    # log.debug "configuration::set", @conf
    return this

  setValues: (values) ->
    Object.keys(values).forEach (key) => @conf[key] = values[key]
    if Configuration.validationRules.email(@conf.email)
      @conf.username = @extractUsername(@conf.email)

  extractUsername: (email) ->
    account = email.substring(0, email.indexOf('@'))
    result = account.replace(/[^\w]/g, '').toLowerCase()
    # log.debug email, " -> ", result
    return result

  save: () ->
    log.debug "AdvancedWebEditor::save", FILE_PATH
    s = CSON.stringify(@conf)
    #@confFile.create().then =>
    @confFile.writeSync(s)
    # log.debug "configuration::save", @conf

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

keys = Object.keys(Configuration.labels)
module.exports = Configuration