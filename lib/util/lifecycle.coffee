git = require './git'
path = require 'path'
moment = require 'moment'

Configuration = require './configuration'
{ Directory } = require 'atom'
{ lstatSync, readdirSync, existsSync } = require('fs')
{ join } = require('path')
branchRegex = /\/feature\/(\d+)\/(\w+)\/(\d+)/

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

getRepoName = (uri) ->
  tmp = uri.split('/')
  name = tmp[tmp.length-1]
  # check for the case when user copied from right panel in github with .git ending
  tmp = name.split('.')
  [..., last] = tmp
  if last is 'git'
    name = tmp[...-1].join('.')
  else
    name

class LifeCycle

  constructor: () ->
    @configuration = new Configuration()

  getConfiguration: () ->
    return @configuration

  saveConfiguration: () ->
    @configuration.save()

  reloadConfiguration: () ->
    return @configuration.read()

  isConfigurationValid: () ->
    return @configuration.exists() && @configuration.isValid()

  haveToClone: () ->
    dir = new Directory(@whereToClone())
    exists = dir.existsSync()
    isEmpty = dir.getEntriesSync().length == 0
    return !exists || (exists && isEmpty)

  # return actual clone path
  whereToClone: () ->
    conf = @configuration.get()
    cloneDir = conf["cloneDir"]
    repoUrl = conf["repoUrl"]
    repoName = getRepoName repoUrl
    return path.join(cloneDir, repoName)

  isProjectPathsOpen: () ->
    openedPaths = atom.project.getPaths()
    # projectPaths = getDirectories(@configuration.get("cloneDir"))
    projectPath = @whereToClone()

    # return existsAllIn(openedPaths, projectPaths) && existsAllIn(projectPaths, openedPaths)
    return elementInList(projectPath, openedPaths)

  openProjectFolder: () ->
    openedPaths = atom.project.getPaths()
    projectPath = @whereToClone()

    shouldOpen = true

    if !@configuration.get()["advancedMode"]
      openedPaths.forEach (x) ->
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

  indexOfProject: () ->
    dirs = atom.project.getDirectories()
    dir = @whereToClone()
    i = 0
    for d in dirs
      p = d.path
      if p == dir
        # console.log "Index is #{i}"
        return i
      i++
    return -1

  doCommit: () ->
    git.setProjectIndex @indexOfProject()

    return git.status().then (files) ->
      return files
    .then (files) ->
      toAdd = files.filter (f) ->
        f.type != "deleted"
      .map (f) -> f.name
      git.add(toAdd)
      return files
    .then (files) ->
      toRemove = files.filter (f) ->
        f.type == "deleted"
      .map (f) -> f.name

      git.remove(toRemove)
    .then -> git.commit()
    .then -> atom.notifications.addSuccess("Changes have been saved succesfully. Publish them when you are ready.")

  doPublish: () ->
    git.setProjectIndex @indexOfProject()
    return git.pushAll()

  updateDevelop: () ->
    console.log "Update develop"
    return git.checkout "develop"
      .then () ->
        git.pull()

  getBranchesByUser: (username) ->
    return git.getBranches().then (branches) ->
      # console.log branches
      branches.remote.filter (b) -> b.indexOf("/#{username}/") >= 0

  suggestNewBranchName: () ->
    console.log "suggestNewBranchName"
    username = @configuration.get()["username"]
    return @getBranchesByUser(username).then (userBranches) ->
      months = userBranches
        .map (b) ->
          m = b.match branchRegex
          return if m? then Number.parseInt(m[1]) else undefined #month
        .filter (x) -> x

      now = moment()
      thisMonth = now.format("YYYYMM")
      maxMonth = if months.length > 0 then String(Math.max.apply(months)) else thisMonth

      monthAsDate = moment(maxMonth, "YYYYMM")
      thisMonthAsDate = moment(thisMonth, "YYYYMM")
      if monthAsDate.diff(thisMonthAsDate) < 0
        maxMonth = thisMonth # it will be the first branch this month

      # retain only maxMonth branch and pick maximum
      numbers = userBranches
        .filter (b) -> b.indexOf(maxMonth) >= 0
        .map (b) ->
          n = b.match branchRegex
          return if m? then Number.parseInt(m[3]) else undefined # final number
        .filter (x) -> x

      max = if numbers.length > 0 then  Math.max.apply(numbers) else 0

      return "/feature/#{maxMonth}/#{username}/#{max + 1}"

module.exports = LifeCycle
