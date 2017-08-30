ConfigurationView = require './advanced-web-editor-view'
BranchView = require './branch-view'

{CompositeDisposable} = require 'atom'
q = require 'q'

LifeCycle = require './util/lifecycle'
Configuration = require './util/configuration'
git = require './util/git'

module.exports = AdvancedWebEditor =
  configurationView: null
  branchView: null
  panel: null
  modalPanel: null
  subscriptions: null

  consumeToolBar: (getToolBar) ->
    @toolBar = getToolBar('advanced-web-editor')
    @lifeCycle.setupToolbar(@toolBar) if @lifeCycle?

  initialize: ->

  activate: (state) ->
    console.log "AdvancedWebEditor::activate", state

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:configure': => @configure()

    # Register publishing commands
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:start': => @commandStartEditing()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:save': => @commandSaveLocally()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:publish': => @commandPublish()

    # @subscriptions.add atom.workspace.observeTextEditors (editor) ->
    #   console.log editor.getPath()

    @subscriptions.add atom.workspace.observeActivePane (pane) ->
      console.log pane

    @subscriptions.add atom.project.onDidChangePaths (paths) ->
      console.log "Atom projects path changed", paths
      console.log atom.project.getRepositories()

    # Check configuration first
    @lifeCycle = new LifeCycle()
    @lifeCycle.setupToolbar(@toolBar) if @toolBar?
    if !@lifeCycle.isConfigurationValid()
      console.log "Configuration required"
      @configure()
    else
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

  hideConfigure: ->
    console.log 'AdvancedWebEditor hidden configuration'
    @panel.destroy()
    @panel = null
    @lifeCycle.reloadConfiguration() #reset configuration

  configure: ->
    console.log 'AdvancedWebEditor shown configuration'
    if @panel?
      return

    @configurationView = new ConfigurationView(@lifeCycle.getConfiguration(),
      () => @saveConfig(),
      () => @hideConfigure()
    )
    @panel = atom.workspace.addTopPanel(item: @configurationView.getElement(), visible: false)
    @panel.show()

  saveConfig: ->
    console.log "Save configuration"
    confValues = @configurationView.readConfiguration()
    config = @lifeCycle.getConfiguration()
    config.set(confValues)
    validationMessages = config.validateAll().map (k) ->
      Configuration.reasons[k]
    if validationMessages.length == 0
      @lifeCycle.saveConfiguration()
      @lifeCycle.gitConfig confValues["fullName"], confValues["email"]
        .then () =>
          @hideConfigure()
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
    configuration = @lifeCycle.getConfiguration()
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

  checkUncommittedChanges: () ->
    console.log "checkUncommittedChanges"
    git.setProjectIndex @lifeCycle.indexOfProject()
    return git.status().then (output) -> output && output.length > 0

  checkUnpublishedChanges: () ->
    console.log "checkUnpublishedChanges"
    git.setProjectIndex @lifeCycle.indexOfProject()
    return git.unpushedCommits()

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
        @branchView = new BranchView(
          branches,
          (branch) => @answerUseBranch branch,
          () => @answerCreateNewBranch()
        )
        @modalPanel = atom.workspace.addModalPanel
          item: @branchView
          visible: true

  answerUseBranch: (branch) ->
    @lifeCycle.isBranchRemote(branch).then (isRemote) =>
      branch = "origin/" + branch if isRemote
      git.checkout(branch, isRemote).then =>
        git.setProjectIndex @lifeCycle.indexOfProject()
        @lifeCycle.statusStarted()
        @lifeCycle.setupToolbar(@toolBar)
        @modalPanel?.hide()
        @modalPanel?.destroy()
        @modalPanel = null
        @branchView?.destroy()
        @branchView = null

  answerCreateNewBranch: () ->
    console.log "Answer: create new branch"
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
    @lifeCycle.doCommit()
      .then () =>
        @lifeCycle.statusSaved()
        @lifeCycle.setupToolbar(@toolBar)
      .fail (e) => atom.notifications.addError "Error occurred",
        description: e.message + "\n" + e.stdout

        @lifeCycle.statusStarted()
        @lifeCycle.setupToolbar(@toolBar)

  commandPublish: () ->
    console.log "Command: Publish"
    git.setProjectIndex @lifeCycle.indexOfProject()
    @lifeCycle.statusPublishing()
    @lifeCycle.setupToolbar(@toolBar)
    @lifeCycle.doPublish().then () =>
      @lifeCycle.statusReady()
      @lifeCycle.setupToolbar(@toolBar)
    .fail (e) =>
      atom.notifications.addError "Error occurred",
        description: e.message + "\n" + e.stdout
      @lifeCycle.statusSaved()
      @lifeCycle.setupToolbar(@toolBar)

  doPreStartCheck: () ->
    deferred = q.defer()
    @lifeCycle.openProjectFolder()
    @checkUncommittedChanges()
      .then (state) =>
        if state
          return {
            state: "unsaved"
          }
        else
          @checkUnpublishedChanges()
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
          if state != "ok"
            atom.confirm
              message: "Detected #{state.state} changes."
              detailedMessage: "#{branches}Do you want to #{action} them now?"
              buttons:
                Yes: () =>
                  deferred.resolve @doSaveOrPublish(action)
                'Keep editing': -> deferred.resolve true#do Nothing
        else
          @lifeCycle.statusReady()
          return @lifeCycle.updateDevelop()
      .then () =>
        atom.notifications.addInfo("Everything is up to date. Start editing when you are ready")
        @lifeCycle.statusReady()
        deferred.resolve true

      return deferred.promise
