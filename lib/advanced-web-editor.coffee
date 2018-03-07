ConfigurationView = require './advanced-web-editor-view'
BranchView = require './branch-view'
ProgressView = require './util/progress-view'

sysinfo = require './util/sysinfo'
log = require './util/logger'

{CompositeDisposable} = require 'atom'
q = require 'q'

LifeCycle = require './util/lifecycle'
Configuration = require './util/configuration'
git = require './util/git'

FOLDER_SIZE_INTERVAL = 1500

module.exports = AdvancedWebEditor =
  configurationView: null
  branchView: null
  panel: null
  modalPanel: null
  subscriptions: null
  statusCheckInterval: -1
  editorSaveHandle: null
  editorModifyHandle: null
  folderSizeInterval: -1

  consumeToolBar: (getToolBar) ->
    @toolBar = getToolBar('advanced-web-editor')
    @lifeCycle.setupToolbar(@toolBar) if @lifeCycle?

  initialize: ->

  activate: (state) ->
    log.debug "AdvancedWebEditor::activate", state

    # Life Cycle manager handles commands and status
    @lifeCycle = new LifeCycle()

    @subscribeToAtomEvents()
    @lifeCycle.setupToolbar(@toolBar) if @toolBar?

    # Check configuration first
    if !@lifeCycle.isConfigurationValid()
      log.debug "Configuration required"
      @configure()
    else
      git.setProjectIndex @lifeCycle.indexOfProject()
      @init()

  init: () ->
    @lifeCycle.closeAllEditors()
    operations = @getInitialSetupOperations()
    log.debug "Initial setup operations", operations
    if operations.length > 0
      # operations.push(() => @handlePreStartCheck())
      # operations.push () ->
      #   q.fcall () -> atom.packages.triggerActivationHook("advanced-web-editor:ready")
      # Perform initialization steps in sequence
      operations.push () ->
        q.fcall () -> atom.restartApplication()

      # result = operations.reduce(q.when, q(true))

      result = q(true)

      attemptExecution = (f) ->
        deferred = q.defer()
        f()
          .then () ->
            # log.debug "Successful execution, resolve true"
            window.clearInterval @folderSizeInterval if @folderSizeInterval >= 0
            deferred.resolve true
          .fail (e) ->
            # log.debug "Initialization step failed", e
            window.clearInterval @folderSizeInterval if @folderSizeInterval >= 0
            atom.confirm
              message: 'Error occurred in initialization'
              detailedMessage: "Error occurred during initialization:\n#{e.message}"
              buttons:
                Retry: ->
                  attemptExecution(f)
                    .then () ->
                      deferred.resolve true
                'Restart Atom': -> atom.restartApplication()
        return deferred.promise

      i = 0
      operations.forEach (f) ->
        result = result.then () ->
          log.debug "Initialization step #{++i}"
          attemptExecution(f)

    else
      @handlePreStartCheck()

  handlePreStartCheck: () ->
    # log.debug "handlePreStartCheck", this
    log.debug "handlePreStartCheck"
    return @doPreStartCheck()
      .then () =>
        @lifeCycle.setupToolbar(@toolBar)
        atom.packages.triggerActivationHook("advanced-web-editor:ready")
      .fail (e) =>
        @lifeCycle.statusReady()
        @lifeCycle.setupToolbar(@toolBar)
        #TODO: add system information
        log.error "During pre start check", e
        atom.notifications.addError "Error occurred during initialization",
          description: e.message + "\n" + e.stdout
      .done()


  deactivate: ->
    @subscriptions.dispose()
    @configurationView?.destroy()
    @branchView?.destroy()
    @panel?.destroy()
    @panel = null
    @modalPanel?.destroy()
    @modalPanel = null
    @toolBar?.removeItems()
    @toolBar = null

  serialize: ->

  subscribeToAtomEvents: ->
    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:configure': => @configure()

    # Register publishing commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:start': => @commandStartEditing()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:save': => @commandSaveLocally()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:publish': => @commandPublish()

    # Listen to project folders. In basic mode, only project folder is allowed
    @subscriptions.add atom.project.onDidChangePaths (paths) =>
      log.debug "Atom projects path changed", paths
      @lifeCycle.openProjectFolder() if !@lifeCycle.isStatusInit()
      if !@lifeCycle.haveToClone()
        git.setProjectIndex @lifeCycle.indexOfProject()

    # You should not open text editor if status is not started
    @subscriptions.add atom.workspace.observeActiveTextEditor (editor) =>
      @editorSaveHandle?.dispose()
      @editorSaveHandle = null
      @editorModifyHandle?.dispose()
      @editorModifyHandle = null

      if !@lifeCycle.isConfigurationValid()
        return
      # log.debug "Active text editor is now", editor
      if !editor
        return
      path = editor.getPath()
      if @lifeCycle.isPathFromProject(path)
        @editorSaveHandle = editor.onDidSave () =>
          @statusCheck()

        if !@lifeCycle.canOpenTextEditors()
          @commandStartEditing()
        else
          @editorModifyHandle = editor.onDidStopChanging () =>
            log.debug "Did stop changing"
            @lifeCycle.statusStarted()
            @lifeCycle.setupToolbar @toolBar

  hideConfigure: ->
    log.debug 'AdvancedWebEditor hidden configuration'
    @panel.destroy()
    @panel = null
    @lifeCycle.reloadConfiguration() #reset configuration

  configure: ->
    log.debug 'AdvancedWebEditor shown configuration'
    if @panel?
      return

    configuration = @lifeCycle.getConfiguration()
    log.debug "Configuration", configuration
    @configurationView = new ConfigurationView(configuration,
      () => @saveConfig(),
      () => @hideConfigure()
    )
    @panel = atom.workspace.addTopPanel(item: @configurationView.getElement(), visible: false)
    @panel.show()
    @configurationView.forceTabIndex()

  saveConfig: ->
    log.debug "Save configuration"
    confValues = @configurationView.readConfiguration()
    config = @lifeCycle.getConfiguration()
    config.setValues(confValues)
    validationMessages = config.validateAll().map (k) ->
      Configuration.reasons[k]
    if validationMessages.length == 0
      @lifeCycle.saveConfiguration()
      @hideConfigure()
      @lifeCycle.gitConfig confValues["fullName"], confValues["email"]
        .then () => @init()
        .done()
    else
      validationMessages.forEach (msg) ->
        atom.notifications.addError(msg)

  percentage: (value, max) ->
    if value < 0
      return 0
    if value >= max
      return max
    return value / max * 100.0

  doClone: (configuration, message) ->
    # log.debug "doClone", configuration
    @lifeCycle.statusInit()

    cloneUrl = @lifeCycle.assembleCloneUrl(configuration)
    targetDir = @lifeCycle.whereToClone(cloneUrl)

    @folderSizeInterval = -1
    repoSize = -1
    currentSize = 0

    isBitbucketRepo = @lifeCycle.isBitbucketRepo(cloneUrl)

    @lifeCycle.deleteFolderSync targetDir

    return q.fcall () =>
      if isBitbucketRepo
        progress = new ProgressView()
        progress.initialize(message)

        modal = atom.workspace.addModalPanel
          item: progress
          visible: true

        repoUsername = configuration.repoUsername
        repoPassword = configuration.password
        repoOwner = configuration.repoOwner
        repoName = @lifeCycle.getRepoName cloneUrl

        # log.debug repoUsername, repoPassword, repoOwner, repoName

        @lifeCycle.getBitbucketRepoSize(repoUsername, repoPassword, repoOwner, repoName)
          .then (size) =>
            repoSize = size
            promise = git.clone cloneUrl, targetDir
              .then () ->
                window.clearInterval @folderSizeInterval
                modal.destroy()
                # atom.restartApplication()
              # Handle the failure and clear the interval outside
              # .fail () =>
              #   window.clearInterval @folderSizeInterval
              #   modal.destroy()
                # atom.confirm
                #   message: 'Error occurred'
                #   detailedMessage: "Unable to download #{cloneUrl}.\nYou may want to try again or check out your configuration."
                #   buttons:
                #     Configure: => @configure()
                #     Retry: => @doClone(configuration, message)

            @folderSizeInterval = window.setInterval () =>
              @lifeCycle.getFolderSize targetDir
                .then (size) =>
                  currentSize = size
                  log.info "Cloning", currentSize, repoSize
                  progress.setProgress @percentage(currentSize, repoSize)
                .fail () -> #maybe not yet there
            , FOLDER_SIZE_INTERVAL
            return promise

          # Let it fail and be handled by retry handler
          # .fail (e) =>
          #   console.log e
          #   modal?.destroy()
          #   atom.confirm
          #     message: 'Error occurred'
          #     detailedMessage: "Unable to gather remote repository size.\nYou may want to try again or check out your configuration."
          #     buttons:
          #       Configure: => @configure()
          #       Retry: => @doClone(configuration, message)
      else
        return git.clone cloneUrl, targetDir

  statusCheck: () ->
    # console.log "statusCheck ->"
    if !@lifeCycle.canCheckGitStatus()
      log.debug "Status check: operations in progress. Skipping."
      return

    q.all [@lifeCycle.checkUncommittedChanges(), @lifeCycle.checkUnpublishedChanges()]
      .then (results) =>
        # log.debug results
        if results[0]
          @lifeCycle.statusStarted()
        else if results[1].length > 0
          @lifeCycle.statusSaved()

        @lifeCycle.setupToolbar @toolBar

  doSaveOrPublish: (action) ->
    promise = null
    if action == "save"
      promise = @lifeCycle.doCommit
      @lifeCycle.statusSaving()
    else if action == "publish"
      promise = @lifeCycle.doPublish
      @lifeCycle.statusPublishing()

    @lifeCycle.setupToolbar(@toolBar)
    promise.bind(@lifeCycle)().then () =>
      if action == "save"
        @lifeCycle.statusSaved()
      else
        @lifeCycle.statusStarted()
      @lifeCycle.setupToolbar(@toolBar)

  askForBranch: ->
    advancedMode = @lifeCycle.getConfiguration().get()["advancedMode"]
    if !advancedMode
      return @answerCreateNewBranch()

    log.info 'AdvancedWebEditor ask for branch'
    @lifeCycle.getYourBranches()
      .then (branches) =>
        # console.log branches
        if branches.length > 0
          @branchView = new BranchView(
            branches,
            (branch) => @answerUseBranch branch,
            () => @answerCreateNewBranch()
          )
          @modalPanel = atom.workspace.addModalPanel
            item: @branchView
            visible: true
        else
          @answerCreateNewBranch()
      .fail (error) ->
        atom.notifications.addError "Unable to retrieve your branches. Try again later.",
          description: if error? then error else ''
          dismissable: true

  answerUseBranch: (branch) ->
    @lifeCycle.isBranchRemote(branch).then (isRemote) =>
      @lifeCycle.currentBranch = branch
      branch = "origin/" + branch if isRemote

      # git.setProjectIndex @lifeCycle.indexOfProject()
      git.checkout(branch, isRemote)
        .then ->
          if !isRemote
            return git.pull '',''
          else
            return q.fcall () ->
        .then =>
          @lifeCycle.statusStarted()
          @lifeCycle.setupToolbar(@toolBar)
          @modalPanel?.hide()
          @modalPanel?.destroy()
          @modalPanel = null
          @branchView?.destroy()
          @branchView = null
        .fail (error) ->
          @modalPanel?.hide()
          @modalPanel?.destroy()
          @modalPanel = null
          @branchView?.destroy()
          @branchView = null
          atom.notifications.addError "Error occurred",
            description: e.message + "\n" + e.stdout

  answerCreateNewBranch: () ->
    log.debug "Answer: create new branch"

    # git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusStarted()
    @modalPanel?.hide()
    @modalPanel?.destroy()
    @modalPanel = null
    @branchView?.destroy()
    @branchView = null
    @lifeCycle.setupToolbar(@toolBar)
    @lifeCycle.newBranchThenSwitch()
      .then (branch) =>
        @lifeCycle.currentBranch = branch
        @lifeCycle.statusStarted()
        @lifeCycle.setupToolbar(@toolBar)
        atom.notifications.addInfo("Created branch #{branch}")
      .fail (e) -> atom.notifications.addError "Error occurred",
        description: e.message + "\n" + e.stdout

  commandStartEditing: () ->
    log.info "Command: Start Editing"
    @askForBranch()

  commandSaveLocally: () ->
    log.info "Command: Save Locally"
    # git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusSaving()
    @lifeCycle.setupToolbar(@toolBar)

    # Save project text editors beforehand
    atom.workspace.getTextEditors().forEach (t) =>
      path = t.getPath()
      if @lifeCycle.isPathFromProject(path)
        t.save()

    @lifeCycle.checkUncommittedChanges(true).then (hasUncommittedChanges) =>
      log.debug "Has uncommitted changes?", hasUncommittedChanges
      if hasUncommittedChanges
        @lifeCycle.doCommit()
          .then () =>
            @lifeCycle.statusSaved()
            @lifeCycle.setupToolbar(@toolBar)
          .fail (e) =>
            # Retry once
            log.warn("First commit failed. Retry once. Reason was", e)
            @lifeCycle.doCommit()
              .then () =>
                @lifeCycle.statusSaved()
                @lifeCycle.setupToolbar(@toolBar)
              .fail (e) ->
                atom.notifications.addError "Error occurred",
                description: e.message + "\n" + e.stdout
                @lifeCycle.statusStarted()
                @lifeCycle.setupToolbar(@toolBar)
      else
        atom.notifications.addSuccess("Nothing to save at the moment.")
        @lifeCycle.statusStarted()
        @lifeCycle.setupToolbar(@toolBar)

  commandPublish: () ->
    log.info "Command: Publish"
    # git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusPublishing()
    @lifeCycle.setupToolbar(@toolBar)
    @lifeCycle.doPublish().then () =>
      @lifeCycle.closeAllEditors()
      @lifeCycle.statusReady()
      @lifeCycle.setupToolbar(@toolBar)
    .fail (e) =>
      atom.notifications.addError "Error occurred",
        description: e.message + "\n" + e.stdout
      @lifeCycle.statusSaved()
      @lifeCycle.setupToolbar(@toolBar)

  doPreStartCheck: () ->
    # log.debug "doPrestartCheck", this
    log.debug "doPrestartCheck"
    keepEditing = false
    deferred = q.defer()
    @lifeCycle.openProjectFolder()

    @lifeCycle.deleteGitLock()

    promise = null
    if @lifeCycle.canCheckGitStatus()
      promise = q.fcall () ->
        return {
          state: 'ok'
        }
    else
      promise = @lifeCycle.checkUncommittedChanges(true)
        .then (state) =>
          if state
            return {
              state: "unsaved"
            }
          else
            @lifeCycle.checkUnpublishedChanges(true)
              .then (unpublishedBranches) ->
                # log.debug unpublishedBranches
                if unpublishedBranches.length > 0
                  return {
                    state: "unpublished"
                    branches: unpublishedBranches
                  }
                else
                  return{
                    state: "ok"
                  }

      promise.then (state) =>
        log.debug state
        if state.state != "ok"
          action = 'save' if state.state == 'unsaved'
          action = 'publish' if state.state == 'unpublished'
          branches = ''
          branches = "Involved branches: " + state.branches.join(",") + ".\n" if state.branches?

          atom.confirm
            message: "Detected #{state.state} changes."
            detailedMessage: "#{branches}Do you want to #{action} them now?"
            buttons:
              Yes: () =>
                deferred.resolve @doSaveOrPublish(action)
              'Keep editing': =>
                if action == 'save'
                  #
                else
                  @lifeCycle.checkoutThenUpdate state.branches.sort()[0]
                    .then () -> deferred.resolve true
                    .fail (error) -> deferred.reject error

                @lifeCycle.statusStarted()
                keepEditing = true
                deferred.resolve true

        else
          return @lifeCycle.updateMaster()
      .then () =>
        return @lifeCycle.updateDevelop() if !keepEditing
      .then () =>
        if !keepEditing
          atom.notifications.addInfo("Everything is up to date. Start editing when you are ready")
          @lifeCycle.statusReady()
        else
          @statusCheck()
        deferred.resolve true
      .fail (e) =>
        #TODO: add sysinfo
        log.error e
        @lifeCycle.statusReady()
        deferred.reject e

      return deferred.promise

  getInitialSetupOperations: () ->
    operations = []

    if @lifeCycle.haveToClone()
      operations.push () => @doClone(@lifeCycle.getConfiguration().get(), "Downloading content project...")

    if @lifeCycle.haveToClonePreviewEngine()
      operations.push () => @doClone(@lifeCycle.getConfiguration().readPreviewConf(), "Downloading preview engine...")
      operations.push () => @lifeCycle.initializePreviewEngine()
    else if @lifeCycle.haveToInitializePreviewEngine()
      operations.push () => @lifeCycle.initializePreviewEngine()

    return operations
