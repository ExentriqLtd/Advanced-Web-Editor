git = require './git'
Configuration = require './configuration'
{ lstatSync, readdirSync, existsSync } = require('fs')
{ join } = require('path')

isDirectory = (source) ->
  try
    return lstatSync(source).isDirectory()
  catch error
    return false

getDirectories = (source) ->
  readdirSync(source).map(name -> join(source, name)).filter(isDirectory)

elementInList = (dir, directories) ->
  return directories.find dir

existsAllIn = (set1, set2) ->
  count = set1.map (x) ->
    return if elementInList x, set2 then 1 else 0
  .reduce ((a, b) -> a + b), 0
  return count == set2.length

module.exports =
class LifeCycle

  constructor: () ->
    @configuration = new Configuration()

  getConfiguration: () ->
    return @configuration

  isConfigurationValid: () ->
    return @configuration.exists() && @configuration.isValid()

  # return actual clone path
  whereToClone: () ->
    cloneDir = @configuration.get()["cloneDir"]
    if !existsSync(cloneDir)
      return cloneDir
      
    # should clone if the clone directory is empty
    # if the directory is not empty, look up for $(cloneDir)/$(repoName)
    # if this path doesn't exist, then clone there
    # if it exists, return null

  isProjectPathsOpen: () ->
    openedPaths = atom.project.getPaths()
    # projectPaths = getDirectories(@configuration.get("cloneDir"))
    projectPath = @configuration.get("cloneDir")

    # return existsAllIn(openedPaths, projectPaths) && existsAllIn(projectPaths, openedPaths)
    return elementInList(projectPath, openedPaths)

  openProjectFolder: () ->
    openedPaths = atom.project.getPaths()
    projectPath = getDirectories(@configuration.get("cloneDir"))

    shouldOpen = true

    openedPaths.forEach x ->
      if x != projectPath
        atom.project.removePath x
      else
        shouldOpen = false

      if shouldOpen
        atom.project.addPath projectPath

  hasUncommittedChanges: () ->
    # TODO: Implement
    return false

  hasUnpublishedChanges: () ->
    # TODO: Implement
    return false
