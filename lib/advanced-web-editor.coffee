AdvancedWebEditorView = require './advanced-web-editor-view'
{CompositeDisposable} = require 'atom'
LifeCycle = require './util/lifecycle'

module.exports = AdvancedWebEditor =
  advancedWebEditorView: null
  modalPanel: null
  subscriptions: null

  initialize: ->

  activate: (state) ->
    console.log "AdvancedWebEditor::activate", state

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:configure': => @configure()

    # @subscriptions.add atom.workspace.observeTextEditors (editor) ->
    #   console.log editor.getPath()

    @subscriptions.add atom.workspace.observeActivePane (pane) ->
      console.log pane

    @subscriptions.add atom.project.onDidChangePaths (paths) ->
      console.log "Atom projects path changed", paths
      console.log atom.project.getRepositories()

    @lifeCycle = new LifeCycle()
    if !@lifeCycle.isConfigurationValid()
      console.log "Configuration required"

  deactivate: ->
    @modalPanel.destroy()
    @subscriptions.dispose()
    @advancedWebEditorView.destroy()

  serialize: ->
    # advancedWebEditorViewState: @advancedWebEditorView.serialize()

  hideConfigure: ->
    console.log 'AdvancedWebEditor hidden configuration'
    @modalPanel.destroy()

  configure: ->
    console.log 'AdvancedWebEditor shown configuration'
    @advancedWebEditorView = new AdvancedWebEditorView(@lifeCycle.getConfiguration(),
      () => @saveConfig(),
      () => @hideConfigure()
    )
    @modalPanel = atom.workspace.addModalPanel(item: @advancedWebEditorView.getElement(), visible: false)
    @modalPanel.show()

  saveConfig: ->
    console.log "Save configuration"
    confValues = @advancedWebEditorView.readConfiguration()
    @lifeCycle.getConfiguration().set(confValues).save()
    @hideConfigure()
