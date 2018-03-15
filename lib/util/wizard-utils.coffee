{File, Directory} = require 'atom'
q = require 'q'
path = require 'path'

_eval = require './wizard-expr-eval'

utils =
  readJson: (filePath) ->
    # console.log "JSON", filePath
    f = new File(filePath)
    f.read(true)
    .then (fileContent) ->
      return JSON.parse(fileContent)

  readFileBetweenMarkers: (filePath, marker) ->
    deferred = q.defer()
    buffer = ""
    markers = 0
    lineReader = require('readline').createInterface
      input: require('fs').createReadStream(filePath)

    lineReader.on 'line', (line) ->
      if line == marker
        markers++
        return

      if markers > 1
        lineReader.close()

      if markers == 1
        buffer += line
        buffer += "\n"

    lineReader.on 'close', () ->
      deferred.resolve buffer

    return deferred.promise

  listDirectories: (dirPath) ->
    deferred = q.defer()
    d = new Directory(dirPath)
    d.getEntries (error, entries) ->
      if error
        deferred.reject error
      else
        result = entries
          .filter (e) -> e instanceof Directory
          .map (x) -> x.getBaseName()
        deferred.resolve result

    return deferred.promise

  listCategories: (categoriesFileName, value, display) ->
    utils.readJson categoriesFileName
    .then (categories) -> categories.map (x) ->
      value: x[value]
      display: x[display]

  listMarkdownMetas: (dirName, value, display) ->
    # console.log(dirName, value, display)
    utils.listDirectories dirName
    .then (directories) ->
      q.all directories.map (directory) ->
        filename = path.join dirName, directory, 'index.md'
        # console.log "Reading", filename
        utils.readFileBetweenMarkers filename, '---'
        .then (content) ->
          # console.log content
          JSON.parse(content)
    .then (metas) -> metas.map (x) ->
      value: x[value]
      display: x[display]

  eval: (value) -> _eval(value)

module.exports = utils
