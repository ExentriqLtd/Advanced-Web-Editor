git = require './git'
path = require 'path'
fs = require 'fs'
moment = require 'moment'
q = require 'q'
getFolderSize = require 'get-folder-size'

Configuration = require './configuration'
BitBucketManager = require './bitbucket-manager'

PleaseWaitView = require './please-wait-view'

{ Directory, File, BufferedProcess } = require 'atom'

branchRegex = /origin\/feature\/(\d+)\/(\w+)\/(\d+)/
TODAY_FORMAT = "MMM D YYYY - HH:mm"
FORBIDDEN_BRANCHES = ["master", "develop"]
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

elementInList = (dir, directories) ->
  return directories.find dir

getRepoName = (uri) ->
  tmp = uri.split('/')
  name = tmp[tmp.length-1]
  tmp = name.split('.')
  [..., last] = tmp
  if last is 'git'
    name = tmp[...-1].join('.')
  else
    name

class LifeCycle
  currentBranch: null

  constructor: () ->
    @configuration = new Configuration()
    @status = STATUS.INIT
    if @configuration.exists() && @configuration.isValid()
      # git.setProjectIndex @indexOfProject()
      @currentBranch = git.getCurrentBranch()

  statusInit: () ->
    console.log "lifeCycle::statusInit"
    @status = STATUS.INIT
    @_stopObservingBranchSwitch()

  statusReady: () ->
    console.log "lifeCycle::statusReady"
    @status = STATUS.READY
    @_stopObservingBranchSwitch()

  statusStarted: () ->
    console.log "lifeCycle::statusStarted"
    @status = STATUS.STARTED
    @_observeBranchSwitch()

  statusStarting: () ->
    console.log "lifeCycle::statusStarting"
    @status = STATUS.STARTING
    @_observeBranchSwitch()

  statusSaving: () ->
    console.log "lifeCycle::statusSaving"
    @status = STATUS.SAVING
    @_observeBranchSwitch()

  statusSaved: () ->
    console.log "lifeCycle::statusSaved"
    @status = STATUS.SAVED
    @_observeBranchSwitch()

  statusPublishing: () ->
    console.log "lifeCycle::statusPublishing"
    @status = STATUS.PUBLISHING
    @_observeBranchSwitch()

  isStatusInit: () ->
    return @status == STATUS.INIT

  canOpenTextEditors: () ->
    return @status >= STATUS.STARTING || @status == STATUS.INIT

  canCheckGitStatus: () ->
    return @status >= STATUS.STARTED && @status != STATUS.SAVING && @status != STATUS.PUBLISHING

  deleteGitLock: () ->
    if !@isConfigurationValid || @haveToClone()
      return

    theLock = path.join(@whereToClone(), '.git', 'index.lock')
    if fs.existsSync(theLock)
      fs.unlinkSync(theLock)


  setupToolbar: (toolBar) ->
    console.log "lifeCycle::setupToolbar"

    if ! (@startBtn && @saveBtn && @publishBtn)
      toolBar.addButton
        icon: 'gear',
        callback: 'advanced-web-editor:configure',
        tooltip: 'Configure'
        label: 'Config'
        priority: 86

      toolBar.addSpacer
        priority: 87

      @startBtn = toolBar.addButton
        icon: 'zap',
        callback: 'advanced-web-editor:start',
        tooltip: 'Start Editing'
        label: 'Edit'
        priority: 88

      @saveBtn = toolBar.addButton
        icon: 'database',
        callback: 'advanced-web-editor:save',
        tooltip: 'Save Locally'
        label: 'Save'
        priority: 89

      @publishBtn = toolBar.addButton
        icon: 'cloud-upload',
        callback: 'advanced-web-editor:publish',
        tooltip: 'Publish'
        priority: 90

    @startBtn.setEnabled @status == STATUS.READY
    @saveBtn.setEnabled @status == STATUS.STARTED
    @publishBtn.setEnabled @status == STATUS.SAVED

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
    return @_isValidCloneTarget(@whereToClone())

  _isValidCloneTarget: (directory) ->
    dir = new Directory(directory)
    exists = dir.existsSync()
    isEmpty = dir.getEntriesSync().length == 0
    return !exists || (exists && isEmpty)

  # return actual clone path
  whereToClone: (url) ->
    conf = @configuration.get()
    cloneDir = conf["cloneDir"]
    repoUrl = if !url then conf["repoUrl"] else url
    repoName = getRepoName repoUrl
    return path.join(cloneDir, repoName)

  haveToClonePreviewEngine: () ->
    return @_isValidCloneTarget(@whereToClonePreviewEngine())

  whereToClonePreviewEngine: () ->
    previewConf = @configuration.readPreviewConf()
    conf = @configuration.get()
    cloneDir = conf["cloneDir"]
    repoUrl = previewConf["repoUrl"]
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
    # git.setProjectIndex @indexOfProject()
    return git.commitAll().then () =>
      @status = STATUS.SAVED
      atom.notifications.addSuccess("Changes have been saved succesfully. Publish them when you are ready.")

  doTraditionalCommit: () ->
    # git.setProjectIndex @indexOfProject()

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

  #publish current branch only
  doPublish: () ->
    # git.setProjectIndex @indexOfProject()
    conf = @configuration.get()
    repoName = getRepoName(conf.repoUrl)
    prm = new BitBucketManager(conf.repoUsername, conf.password)
    branch = git.getLocalBranch()
    willOpenPr = false
    console.log "Local branch is:", branch

    return prm.getPullRequests(conf.repoOwner, repoName)
      .then (pullRequests) ->
        console.log "Pull requests", pullRequests
        # Filter out branches if pull requests are pending already
        list = pullRequests.map (pr) -> pr.from
        branches = list.filter (b) -> b == branch
        willOpenPr = branches.length == 0
      .then () ->
        git.push '', ''
      .then () =>
        console.log "Will open PR for", branch, willOpenPr
        # Open PRs for remaining branches towards branch develop
        if willOpenPr
          return @openPullRequest(prm, conf.repoOwner, repoName, branch)
        else
          return q.fcall () -> null
      .then (status) =>
        console.log "Pull requests status", status
        #Then notify we're ready for another round
        @status = STATUS.READY
        atom.notifications.addSuccess("Changes have been published succesfully.")

  doPublishAllBranches: () ->
    # git.setProjectIndex @indexOfProject()
    conf = @configuration.get()
    branches = []
    repoName = getRepoName(conf.repoUrl)
    prm = new BitBucketManager(conf.repoUsername, conf.password)
    # First: gather modified branches
    return git.unpushedCommits()
      .then (modifiedBranches) ->
        branches = modifiedBranches
        # Then: gather open pull requests
        return prm.getPullRequests(conf.repoOwner, repoName)
      .then (pullRequests) ->
        console.log "Pull requests", pullRequests
        # Filter out branches if pull requests are pending already
        list = pullRequests.map (pr) -> pr.from
        branches = branches.filter (b) -> list.length == 0 || list.indexOf(b) < 0
        return branches
      .then () ->
        #Then: push all branches
        return git.pushAll()
      .then () =>
        console.log "Will open PR for", branches
        # Open PRs for remaining branches towards branch develop
        return @openPullRequests(prm, branches)
      .then (status) =>
        console.log "Pull requests status", status
        #Then notify we're ready for another round
        @status = STATUS.READY
        atom.notifications.addSuccess("Changes have been published succesfully.")

  openPullRequests: (prm, branches) ->
    conf = @configuration.get()
    repoName = getRepoName(conf.repoUrl)
    return q.all branches.map (b) => @openPullRequest prm, conf.repoOwner, repoName, b

  openPullRequest: (prm, repoOwner, repoName, branch) ->
    today = moment().format(TODAY_FORMAT)
    title = "#{branch} - #{today}"
    description = "Pull request created on #{today}"
    prm.createPullRequest(title, description, repoOwner, repoName, branch, 'develop')
      .then () ->
        return {
          branch: branch
          ok: true
        }
      .fail (error) ->
        return {
          branch: branch
          ok: false
          error: error
        }

  updateMaster: () -> @checkoutThenUpdate 'master', true
  updateDevelop: () -> @checkoutThenUpdate 'develop', true

  checkoutThenUpdate: (branch, doReset) ->
    console.log "Update #{branch}"
    # git.setProjectIndex @indexOfProject()
    return git.checkout branch
      .then () ->
        if !doReset
          git.pull()
        else
          git.status().then (s) ->
            if s.length == 0
              return git.pull()
            else
              return git.resetHard().then () -> git.pull()

  getYourBranches: () ->
    conf = @configuration.get()
    username = conf["username"]
    # console.log username

    if !@isBitbucketRepo() # trust git
      return @getBranchesByUser(username).then (branches) ->
        return branches.map (b) -> b.replace 'origin/', ''
    else #ask API
      bm = new BitBucketManager(conf.repoUsername, conf.password)
      repoName = getRepoName(conf.repoUrl)
      return bm.getBranches(conf.repoOwner, repoName)
        .then (branches) ->
          console.log branches, username
          return branches.filter (b) -> (b not in FORBIDDEN_BRANCHES) && b.indexOf("/#{username}/") >= 0

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

  suggestNewBranchName: (dontAskBitbucket) ->
    console.log "suggestNewBranchName"
    conf = @configuration.get()
    username = conf["username"]
    branches = null
    if dontAskBitbucket || !@isBitbucketRepo() # trust git
      branchesPromise = @getBranchesByUser(username)
    else
      bm = new BitBucketManager(conf.repoUsername, conf.password)
      repoName = getRepoName(conf.repoUrl)
      branchesPromise = bm.getBranches(conf.repoOwner, repoName)
        .then (branches) ->
          console.log branches, username
          return branches.filter (b) -> (b not in FORBIDDEN_BRANCHES) && b.indexOf("/#{username}/") >= 0

    return git.fetch().then () -> branchesPromise.then (userBranches) ->
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
    @suggestNewBranchName(true)
      .then (branch) =>
        b = branch
        @currentBranch = branch
        git.createAndCheckoutBranch branch
      .then () -> return b

  getFolderSize: (folder) ->
    deferred = q.defer()
    getFolderSize folder, (err, size)  ->
      if err
        deferred.reject err
      else
        deferred.resolve size

    return deferred.promise

  isBitbucketRepo: (repoUrl) ->
    theUrl = if !repoUrl then @configuration.get().repoUrl else repoUrl
    return theUrl.indexOf '@bitbucket.org' > 0 || theUrl.indexOf 'bitbucket.org' > 0

  getBitbucketRepoSize: (repoUsername, repoPassword, repoOwner, repoName) ->
    console.log "getBitbucketRepoSize", repoUsername, repoPassword, repoOwner, repoName
    conf = @configuration.get()
    owner = if !repoOwner then conf.repoOwner else repoOwner
    name = if !repoName then getRepoName(conf.repoUrl) else repoName
    username = if repoUsername then repoUsername else conf.repoUsername
    password = if repoPassword then repoPassword else conf.password
    bm = new BitBucketManager(username, password)
    return bm.getRepoSize(owner, name)

  checkUncommittedChanges: (force) ->
    console.log "checkUncommittedChanges"
    if force || @canCheckGitStatus()
      # git.setProjectIndex @indexOfProject()
      if git.isCurrentBranchForbidden()
        return q.fcall () -> false
      return git.status().then (output) -> output && output.length > 0
    else
      console.log "Cannot check at the moment. Operations in progress."
      return q.fcall () -> false

  checkUnpublishedChanges: (force) ->
    console.log "checkUnpublishedChanges"
    if force || @canCheckGitStatus()
      # git.setProjectIndex @indexOfProject()
      return git.unpushedCommits()
        .then (branches) -> branches.filter (b) -> b not in FORBIDDEN_BRANCHES
    else
      console.log "Cannot check at the moment. Operations in progress."
      return q.fcall () -> false

  isPathFromProject: (p) ->
    root = @whereToClone()
    return if (p and root) then p.indexOf(root) >= 0 else false

  getRepoName: getRepoName

  _observeBranchSwitch: () ->
    console.log "_observeBranchSwitch"
    if @branchFileDisposable?
      return
    filePath = path.join(@whereToClone(), '.git', 'HEAD')
    console.log "Going to observe #{filePath}"
    branchFile = new File(filePath, false)
    @branchFileDisposable = branchFile.onDidChange () =>
      branchFile.read()
        .then (content) =>
          branchName = content.replace('ref: refs/heads/', '').trim()
          console.log "Switch happened", branchName, branchName in FORBIDDEN_BRANCHES
          if branchName in FORBIDDEN_BRANCHES || !@configuration.get().advancedMode
            console.log "Reverting switch to", @currentBranch
            git.checkout @currentBranch
          else
            console.log "Switch permitted"
            @currentBranch = branchName

  _stopObservingBranchSwitch: () ->
    console.log "_stopObservingBranchSwitch"
    @branchFileDisposable?.dispose()
    @branchFileDisposable = null

  closeAllEditors: () ->
    atom.workspace.getTextEditors().forEach (t) =>
      p = t.getPath()
      if @isPathFromProject p
        t.destroy()

  isStringEmpty: (s) ->
    return !(s && s.trim && s.trim().length > 0)

  isHttp: (url)->
    return url.startsWith("http")

  assembleCloneUrl: (conf) ->
    if(!@isHttp(conf.repoUrl))
      return conf.repoUrl

    if @isStringEmpty(conf.username)
      return conf.repoUrl
    i = conf.repoUrl.indexOf("//")
    if i < 0
      return conf.repoUrl
    return conf.repoUrl.substring(0, i + 2) + conf.username + ":" + conf.password + "@" + conf.repoUrl.substring(i+2)

  haveToInitializePreviewEngine: () ->
    previewConf = @configuration.readPreviewConf()
    node_modules_dir = path.join(@whereToClonePreviewEngine(), 'node_modules')
    # same requirements: either doesn't exist or is empty
    return @_isValidCloneTarget(node_modules_dir)

  initializePreviewEngine: () ->
    deferred = q.defer()
    view = new PleaseWaitView()
    view.initialize("Initializing preview engine. Please wait...")
    modal = atom.workspace.addModalPanel(item: view, visible:true)
    @_doInitializePreviewEngine()
      .then () ->
        modal.destroy()
        deferred.resolve true
      .fail (e) ->
        modal.destroy()
        # atom.notifications.addError("Error occurred", description: "Error occurred during initialization", detail: e.message, dismissable: true)
        deferred.reject e

    return deferred.promise

  _doInitializePreviewEngine: () ->
    cwd = @whereToClonePreviewEngine()

    deferred = q.defer()

    errors = []
    command = "npm"
    args = ["install"]

    stdout = (output) -> console.log "npm >", output

    stderr = (output) ->
      stream = console.error
      if output.indexOf('WARN') > 0
        stream = console.log
      else
        errors.push output

      stream "npm >", output

    exit = (code) ->
      console.log("npm exited with #{code}")

      if code != 0
        console.log "npm failed"
        deferred.reject message:errors.join "\n"
      else
        console.log "npm successful"
        deferred.resolve true

    options =
      cwd: cwd
    npmProcess = new BufferedProcess({command, args, options, stdout, stderr, exit})

    return deferred.promise

module.exports = LifeCycle
