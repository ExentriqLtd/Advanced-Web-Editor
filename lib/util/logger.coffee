winston = require 'winston'
Transport = require 'winston-transport'
request = require 'request'
q = require 'q'
path = require 'path'
mkdirp = require 'mkdirp'
sysinfo = require './sysinfo'

{ Directory } = require 'atom'

HttpLogConfiguration = require './http-log-configuration'
Configuration = require './configuration'
packageInfo = require '../../package.json'

logConf = new HttpLogConfiguration()
LOG_FILE = "#{packageInfo.name}.log"

class CustomHttpTransport extends Transport
  constructor: (@opts) ->
    console.log @opts
    super(@opts)

  _post: (msg, meta) ->
    deferred = q.defer()

    options =
      url: @opts.endpoint
      json:
        msg: msg
        meta: meta
        sysinfo: sysinfo()

    console.log "Requesting", options

    request.post options, (error, response, body) ->
      try
        if error
          deferred.reject msg: "Error occurred, Resource #{options.url}", err: error
        else if response && response.statusCode != 200
          deferred.reject msg: "HTTP error #{response.statusCode}, Resource #{options.url}", code: response.statusCode
        else
          deferred.resolve body
      catch e
        deferred.reject e

    return deferred.promise

  log: (level, msg, meta, callback) ->
    # setImmediate () =>
    #   @emit('logged', info)

    @_post(msg, meta).then () ->
      if callback
        callback()
    .catch (err) -> console.log "Unable to POST log", err
    .done()

aweConf = new Configuration()
cloneDir = aweConf.get().cloneDir
logDir = path.join(cloneDir, 'logs')

dirExists = (dir) ->
  d = new Directory(dir)
  return d.existsSync()

buildTransports = () ->
  transports = [
    new winston.transports.Console()
  ]

  if dirExists(cloneDir)
    transports.push new winston.transports.File({ filename: path.join(logDir, LOG_FILE) })

  if logConf.exists()
    transports.push new CustomHttpTransport({ level: 'error', endpoint: logConf.get().endpoint}),

  return transports

ld = new Directory(logDir)

# TODO: what if confDir don't exist yet?
if !dirExists logDir
  mkdirp.sync logDir

logger = new winston.Logger
  level: 'debug',
  exitOnError: false
  transports: buildTransports()

module.exports = logger
