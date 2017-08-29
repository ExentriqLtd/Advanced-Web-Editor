git = require './git'
path = require 'path'
moment = require 'moment'

Configuration = require './configuration'
{ Directory } = require 'atom'
{ lstatSync, readdirSync, existsSync } = require('fs')
{ join } = require('path')
branchRegex = /origin\/feature\/(\d+)\/(\w+)\/(\d+)/
STATUS =
  'INIT': 0
  'READY': 1
  'STARTING': 2
  'STARTED': 3
  'SAVING' : 4
  'SAVED': 5
  'PUBLISHING': 6

  resolve: (status) ->
    return Object.keys(STATUS)
      .find (k) -> typeof(k) != "function" && STATUS[k] == status

isDirectory = (source) ->
  try
    return lstatSync(source).isDirectory()
  catch error
    return false

getDirectories = (source) ->
  readdirSync(source).map(name -> join(source, name)).filter(isDirectory)

elementInList = (dir, directories) ->
  return directories.find dir

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
    @status = STATUS.INIT

  statusReady: () ->
    @status = STATUS.READY

  statusStarted: () ->
    @status = STATUS.STARTED

  statusStarting: () ->
    @status = STATUS.STARTING

  statusSaving: () ->
    @status = STATUS.SAVING

  statusSaved: () ->
    @status = STATUS.SAVED

  statusPublishing: () ->
    @status = STATUS.PUBLISHING

  setupToolbar: (toolBar) ->
    toolBar.removeItems()

    toolBar.addButton
      icon: 'gear',
      callback: 'advanced-web-editor:configure',
      tooltip: 'Configure'
      priority: 86

    toolBar.addSpacer
      priority: 87

    startBtn = toolBar.addButton
      icon: 'zap',
      callback: 'advanced-web-editor:start',
      tooltip: 'Start Editing'
      priority: 88

    saveBtn = toolBar.addButton
      icon: 'database',
      callback: 'advanced-web-editor:save',
      tooltip: 'Save Locally'
      priority: 89

    publishBtn = toolBar.addButton
      icon: 'cloud-upload',
      callback: 'advanced-web-editor:publish',
      tooltip: 'Publish'
      priority: 90

    startBtn.setEnabled @status == STATUS.READY
    saveBtn.setEnabled @status == STATUS.STARTED
    publishBtn.setEnabled @status == STATUS.SAVED

  getConfiguration: () ->
    return @configuration

  saveConfiguration: () ->
    @configuration.save()

  reloadConfiguration: () ->
    return @configuration.read()

  isConfigurationValid: () ->
    return @configuration.exists() && @configuration.isValid()

  gitConfig: (username, email) ->
    return git.gitConfig(username, email)

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
    projectPath = @whereToClone()
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
    .then =>
      @status = STATUS.SAVED
      atom.notifications.addSuccess("Changes have been saved succesfully. Publish them when you are ready.")

  doPublish: () ->
    git.setProjectIndex @indexOfProject()
    return git.pushAll()
      .then () =>
        @status = STATUS.READY
        atom.notifications.addSuccess("Changes have been published succesfully.")

  updateDevelop: () ->
    console.log "Update develop"
    return git.checkout "develop"
      .then () ->
        git.pull()

  getYourBranches: () ->
    username = @configuration.get()["username"]
    return @getBranchesByUser(username).then (branches) ->
      return branches.map (b) -> b.replace 'origin/', ''

  getBranchesByUser: (username) ->
    return git.getBranches().then (branches) ->
      # console.log branches
      branches.remote.filter (b) -> b.indexOf("/#{username}/") >= 0

  isBranchRemote: (branch) ->
    return git.getBranches().then (branches) ->
      isRemote = branches.remote
        .filter (b) -> b == 'origin/' + branch
        .length > 0
      isLocal = branches.local
        .filter (b) -> b == branch
        .length > 0
      console.log branches, isRemote, isLocal, branch
      return isRemote && !isLocal

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

      chooseMax = (list, defaultValue) ->
        if list.length == 1
          res = list[0]
        else if list.length == 0
          res = defaultValue
        else
          res = Math.max.apply(null, list)

        return res

      maxMonth = String(chooseMax(months, thisMonth))

      monthAsDate = moment(maxMonth, "YYYYMM")
      thisMonthAsDate = moment(thisMonth, "YYYYMM")
      if monthAsDate.diff(thisMonthAsDate) < 0
        maxMonth = thisMonth # it will be the first branch this month

      # retain only maxMonth branch and pick maximum
      numbers = userBranches
        .filter (b) -> b.indexOf('/' + maxMonth + '/') >= 0
        .map (b) ->
          n = b.match branchRegex
          return if n? then Number.parseInt(n[3]) else undefined # final number
        .filter (x) -> x

      max = chooseMax(numbers, 0)

      return "feature/#{maxMonth}/#{username}/#{max + 1}"

  newBranchThenSwitch: () ->
    b = ""
    @suggestNewBranchName()
      .then (branch) ->
        b = branch
        git.createAndCheckoutBranch branch
      .then () -> return b

module.exports = LifeCycle
