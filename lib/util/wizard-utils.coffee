{File, Directory} = require 'atom'
q = require 'q'
path = require 'path'
readline = require('readline')
fs = require('fs')
sanitize = require('sanitize-filename')

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

    fs.access filePath, (err) ->
      if err
        deferred.resolve null
      else
        lineReader = readline.createInterface
          input: fs.createReadStream(filePath)

        lineReader.on 'line', (line) ->
          if line == marker
            markers++
            return

          if markers > 1
            lineReader.close()

          if markers == 1
            buffer += line
            buffer += "\n"

        lineReader.on 'error', (error) ->
          console.error "During readFileBetweenMarkers", error
          deferred.resolve null

        lineReader.on 'close', () ->
          deferred.resolve buffer

    return deferred.promise

  listDirectoriesSync: (dirPath) ->
    d = new Directory(dirPath)
    return d.getEntriesSync()
    .filter (e) -> e instanceof Directory
    .map (x) -> x.getBaseName()

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

  dirExists: (dirPath) ->
    d = new Directory(dirPath)
    return d.exists()

  dirExistsSync: (dirPath) ->
    d = new Directory(dirPath)
    return d.existsSync()

  titleToDirectoryName: (title) ->
    return sanitize(title).replace(/\s/g, '-')

  listCategories: (categoriesFileName, value, display) ->
    utils.readJson categoriesFileName
    .then (categories) ->
      if !categories
        return []

      return categories.map (x) ->
        value: x[value]
        display: x[display]
    .catch (error) ->
      console.error "During listCategories", error
      return []

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
          try
            return JSON.parse(content)
          catch error
            console.error "Parsing metadata", error
            return null
        .fail () ->
          return null
    .then (metas) ->
      # console.log metas, metas.length, metas.filter((x) -> x).length
      return metas.filter((x) -> x != null)
      .map (x) ->
        value: x[value]
        display: x[display]

  eval: (value) -> _eval(value)

module.exports = utils
