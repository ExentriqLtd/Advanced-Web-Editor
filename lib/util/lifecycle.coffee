git = require './git'
Configuration = require './configuration'
{ lstatSync, readdirSync } = require('fs')
{ join } = require('path')

isDirectory = (source) -> lstatSync(source).isDirectory()
getDirectories = (source) ->
  readdirSync(source).map(name -> join(source, name)).filter(isDirectory)

existsDir = (dir, directories) ->
  return directories.find dir

existsAllIn = (set1, set2) ->
  count = set1.map (x) ->
    return if existsDir x, set2 then 1 else 0
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

  isProjectPathsOpen: () ->
    openedPath = atom.project.getPaths()
    projectPaths = getDirectories(@configuration.get("cloneDir"))

    return existsAllIn(openedPath, projectPaths) && existsAllIn(projectPaths, openedPath)

  openProjectFolders: () ->
    openedPath = atom.project.getPaths()
    projectPaths = getDirectories(@configuration.get("cloneDir"))

    openedPath.forEach x ->
      if !existsDir x, projectPaths
        atom.project.removePath x

    projectPaths.forEach x ->
      if !existsDir x, openedPath
        atom.project.addPath x

  hasUncommittedChanges: () ->
    # TODO: Implement
    return false

  hasUnpublishedChanges: () ->
    # TODO: Implement
    return false
