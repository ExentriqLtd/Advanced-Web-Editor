{File, Directory} = require 'atom'
q = require 'q'
path = require 'path'

utils =
  readJson: (filePath) ->
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

  listCategories: (maprDir, categoriesFileName) ->
    f = categoriesFileName
    if f.startsWith '/'
      f = categoriesFileName.substring(1)
    pathElements = f.split '/'
    fileName = path.join maprDir, pathElements...
    return utils.readJson fileName

  listMarkdownMetas: (maprContentDir, subpath) ->
    d = subpath
    if d.startsWith '/'
      d = subpath.substring(1)
    pathElements = d.split '/'
    dirName = path.join maprContentDir, pathElements...
    utils.listDirectories dirName
    .then (directories) ->
      q.all directories.map (directory) ->
        filename = path.join dirName, directory, 'index.md'
        utils.readFileBetweenMarkers filename, '---'
        .then (content) ->
          console.log content
          JSON.parse(content)

module.exports = utils
