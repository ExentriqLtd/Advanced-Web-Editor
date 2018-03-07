{app} = require 'remote'
path = require 'path'
CSON = require 'cson'
{File, Directory} = require 'atom'

HTTP_LOG_CONF = path.join(app.getPath("userData"), "http-log.cson")

class HttpLogConfiguration
  constructor: () ->
    @read()

  read: () ->
    console.log "HttpLogConfiguration::read", HTTP_LOG_CONF
    @confFile = new File(HTTP_LOG_CONF)
    if @exists()
      try
        @conf = CSON.parseCSONFile(HTTP_LOG_CONF)
      catch error
        console.warn "Invalid HTTP log configuration detected", error
        @conf = null

  get: ->
    return @conf

  exists: ->
    return @conf != null

module.exports = HttpLogConfiguration
