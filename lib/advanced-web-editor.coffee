ConfigurationView = require './advanced-web-editor-view'
BranchView = require './branch-view'
ProgressView = require './util/progress-view'

{CompositeDisposable} = require 'atom'
q = require 'q'

LifeCycle = require './util/lifecycle'
Configuration = require './util/configuration'
git = require './util/git'

STATUS_CHECK_INTERVAL = 25000
FOLDER_SIZE_INTERVAL = 1500

module.exports = AdvancedWebEditor =
  configurationView: null
  branchView: null
  panel: null
  modalPanel: null
  subscriptions: null
  statusCheckInterval: -1
  editorHandle: null

  consumeToolBar: (getToolBar) ->
    @toolBar = getToolBar('advanced-web-editor')
    @lifeCycle.setupToolbar(@toolBar) if @lifeCycle?

  initialize: ->

  activate: (state) ->
    console.log "AdvancedWebEditor::activate", state

    # Life Cycle manager handles commands and status
    @lifeCycle = new LifeCycle()

    @subscribeToAtomEvents()
    @lifeCycle.setupToolbar(@toolBar) if @toolBar?

    # Check configuration first
    if !@lifeCycle.isConfigurationValid()
      console.log "Configuration required"
      @configure()
    else
      @lifeCycle.closeAllEditors()
      if @lifeCycle.haveToClone()
        @askForClone()
      else
        @doPreStartCheck()
          .then () =>
            @lifeCycle.setupToolbar(@toolBar)
          .fail (e) =>
            @lifeCycle.statusReady()
            @lifeCycle.setupToolbar(@toolBar)
            console.log e.message, e.stdout
            atom.notifications.addError "Error occurred during initialization",
              description: e.message + "\n" + e.stdout


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
    # advancedWebEditorViewState: @configurationView.serialize()

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
      console.log "Atom projects path changed", paths
      @lifeCycle.openProjectFolder() if  !@lifeCycle.isStatusInit()

    # You should not open text editor if status is not started
    @subscriptions.add atom.workspace.observeActiveTextEditor (editor) =>
      if !@lifeCycle.isConfigurationValid()
        return
      console.log "Active text editor is now", editor
      if !editor
        @editorHandle?.dispose()
        @editorHandle = null
        return
      path = editor.getPath()
      if @lifeCycle.isPathFromProject(path)
        @editorHandle?.dispose()
        @editorHandle = editor.onDidSave () =>
          @statusCheck()
        if !@lifeCycle.canOpenTextEditors()
          @commandStartEditing()

  hideConfigure: ->
    console.log 'AdvancedWebEditor hidden configuration'
    @panel.destroy()
    @panel = null
    @lifeCycle.reloadConfiguration() #reset configuration

  configure: ->
    console.log 'AdvancedWebEditor shown configuration'
    if @panel?
      return

    configuration = @lifeCycle.getConfiguration()
    console.log "Configuration", configuration
    @configurationView = new ConfigurationView(configuration,
      () => @saveConfig(),
      () => @hideConfigure()
    )
    @panel = atom.workspace.addTopPanel(item: @configurationView.getElement(), visible: false)
    @panel.show()

  saveConfig: ->
    console.log "Save configuration"
    confValues = @configurationView.readConfiguration()
    config = @lifeCycle.getConfiguration()
    config.setValues(confValues)
    validationMessages = config.validateAll().map (k) ->
      Configuration.reasons[k]
    if validationMessages.length == 0
      @lifeCycle.saveConfiguration()
      @lifeCycle.gitConfig confValues["fullName"], confValues["email"]
        .then () ->
          atom.restartApplication()
          # @hideConfigure()
          # if @lifeCycle.haveToClone()
          #   @askForClone()
          # else
          #   @doPreStartCheck()
          #     .then () =>
          #       @lifeCycle.setupToolbar(@toolBar)
          #     .fail (e) =>
          #       @lifeCycle.statusReady()
          #       @lifeCycle.setupToolbar(@toolBar)
          #       console.log e.message, e.stdout
          #       atom.notifications.addError "Error occurred during initialization",
          #         description: e.message + "\n" + e.stdout
    else
      validationMessages.forEach (msg) ->
        atom.notifications.addError(msg)

  askForClone: () ->
    atom.confirm
      message: 'Information: Download about to start'
      detailedMessage: 'Your repository will be downloaded. It may take a long time.'
      buttons:
        OK: => @doClone()
        # No: -> () -> {}

  doClone: () ->
    console.log "doClone"
    @lifeCycle.statusInit()
    configuration = @lifeCycle.getConfiguration()

    folderSizeInterval = -1
    repoSize = -1
    currentSize = 0

    isBitbucketRepo = @lifeCycle.isBitbucketRepo()

    percentage = (value, max) ->
      if value < 0
        return 0
      if value >= max
        return max
      return value / max * 100.0

    callGitClone = () =>
      git.clone configuration.assembleCloneUrl(), @lifeCycle.whereToClone()
        .then (output) =>
          console.log output
          atom.notifications.addSuccess("Repository cloned succesfully")
          @doPreStartCheck()
            .then () =>
              @lifeCycle.setupToolbar(@toolBar)
            .fail (e) ->
              console.log e.message, e.stdout
              atom.notifications.addError "Error occurred during initialization",
                description: e.message + "\n" + e.stdout
        .fail (e) =>
          console.log e
          atom.confirm
            message: 'Error occurred'
            detailedMessage: "An error occurred during git clone:\n#{e.message}\n#{e.stdout}\n\nYou may want to try again or check out your configuration."
            buttons:
              Configure: => @configure()
              Retry: => @doClone()

    return q.fcall () =>
      if isBitbucketRepo
        progress = new ProgressView()
        progress.initialize()

        modal = atom.workspace.addModalPanel
          item: progress
          visible: true

        @lifeCycle.getBitbucketRepoSize()
          .then (size) =>
            repoSize = size
            promise = callGitClone()
              .then () ->
                window.clearInterval folderSizeInterval
                modal.destroy()
                atom.restartApplication()
              .fail () =>
                window.clearInterval folderSizeInterval
                modal.destroy()
                atom.confirm
                  message: 'Error occurred'
                  detailedMessage: "Unable to download the project.\nYou may want to try again or check out your configuration."
                  buttons:
                    Configure: => @configure()
                    Retry: => @doClone()

            folderSizeInterval = window.setInterval () =>
              @lifeCycle.getFolderSize @lifeCycle.whereToClone()
                .then (size) ->
                  currentSize = size
                  console.log "Cloning", currentSize, repoSize
                  progress.setProgress percentage(currentSize, repoSize)
                .fail () -> #maybe not yet there
            , FOLDER_SIZE_INTERVAL
            return promise

          .fail (e) =>
            console.log e
            modal?.destroy()
            atom.confirm
              message: 'Error occurred'
              detailedMessage: "Unable to gather remote repository size.\nYou may want to try again or check out your configuration."
              buttons:
                Configure: => @configure()
                Retry: => @doClone()
      else
        return callGitClone()

  statusCheck: () ->
    # console.log "statusCheck ->"
    if !@lifeCycle.canCheckGitStatus()
      console.log "Status check: operations in progress. Skipping."
      return

    q.all [@lifeCycle.checkUncommittedChanges(), @lifeCycle.checkUnpublishedChanges()]
      .then (results) =>
        # console.log results
        if results[0]
          @lifeCycle.statusStarted()
        else if results[1].length > 0
          @lifeCycle.statusSaved()

        @lifeCycle.setupToolbar @toolBar

  # startStatusCheck: () ->
  #   @statusCheckInterval= window.setInterval () =>
  #     @statusCheck()
  #   , STATUS_CHECK_INTERVAL if @statusCheckInterval < 0
  #
  # stopStatusCheck: () ->
  #   window.clearInterval @statusCheckInterval
  #   @statusCheckInterval = -1

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

    console.log 'AdvancedWebEditor ask for branch'
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
          description: error
          dismissable: true

  answerUseBranch: (branch) ->
    @lifeCycle.isBranchRemote(branch).then (isRemote) =>
      @lifeCycle.currentBranch = branch
      branch = "origin/" + branch if isRemote

      git.setProjectIndex @lifeCycle.indexOfProject()
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
          # @startStatusCheck()
        .fail (error) ->
          @modalPanel?.hide()
          @modalPanel?.destroy()
          @modalPanel = null
          @branchView?.destroy()
          @branchView = null
          atom.notifications.addError "Error occurred",
            description: e.message + "\n" + e.stdout

  answerCreateNewBranch: () ->
    console.log "Answer: create new branch"
    @lifeCycle.currentBranch = branch
    git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusStarted()
    @modalPanel?.hide()
    @modalPanel?.destroy()
    @modalPanel = null
    @branchView?.destroy()
    @branchView = null
    @lifeCycle.setupToolbar(@toolBar)
    @lifeCycle.newBranchThenSwitch()
      .then (branch) =>
        @lifeCycle.statusStarted()
        @lifeCycle.setupToolbar(@toolBar)
        # @startStatusCheck()
        atom.notifications.addInfo("Created branch #{branch}")
      .fail (e) -> atom.notifications.addError "Error occurred",
        description: e.message + "\n" + e.stdout

  commandStartEditing: () ->
    console.log "Command: Start Editing"
    @askForBranch()

  commandSaveLocally: () ->
    console.log "Command: Save Locally"
    git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusSaving()
    @lifeCycle.setupToolbar(@toolBar)

    @lifeCycle.checkUncommittedChanges().then (hasUncommittedChanges) =>
      console.log "Has uncommitted changes?", hasUncommittedChanges
      if hasUncommittedChanges
        @lifeCycle.doCommit()
          .then () =>
            @lifeCycle.statusSaved()
            @lifeCycle.setupToolbar(@toolBar)
          .fail (e) => atom.notifications.addError "Error occurred",
            description: e.message + "\n" + e.stdout

            @lifeCycle.statusStarted()
            @lifeCycle.setupToolbar(@toolBar)
      else
        atom.notifications.addSuccess("Nothing to save at the moment.")
        @lifeCycle.statusStarted()
        @lifeCycle.setupToolbar(@toolBar)

  commandPublish: () ->
    console.log "Command: Publish"
    git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusPublishing()
    @lifeCycle.setupToolbar(@toolBar)
    @lifeCycle.doPublish().then () =>
      @lifeCycle.closeAllEditors()
      @lifeCycle.statusReady()
      # @stopStatusCheck()
      @lifeCycle.setupToolbar(@toolBar)
    .fail (e) =>
      atom.notifications.addError "Error occurred",
        description: e.message + "\n" + e.stdout
      @lifeCycle.statusSaved()
      @lifeCycle.setupToolbar(@toolBar)

  doPreStartCheck: () ->
    keepEditing = false
    deferred = q.defer()
    @lifeCycle.openProjectFolder()
    @lifeCycle.checkUncommittedChanges()
      .then (state) =>
        if state
          return {
            state: "unsaved"
          }
        else
          @lifeCycle.checkUnpublishedChanges()
            .then (unpublishedBranches) ->
              # console.log unpublishedBranches
              if unpublishedBranches.length > 0
                return {
                  state: "unpublished"
                  branches: unpublishedBranches
                }
              else
                return{
                  state: "ok"
                }
      .then (state) =>
        console.log state
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
                # @startStatusCheck()
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
        console.log e
        @lifeCycle.statusReady()
        deferred.reject e

      return deferred.promise
