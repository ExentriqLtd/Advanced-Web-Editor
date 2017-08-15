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
    @advancedWebEditorView = new AdvancedWebEditorView(state.advancedWebEditorViewState, @closeModal)
    @modalPanel = atom.workspace.addModalPanel(item: @advancedWebEditorView.getElement(), visible: false)

    # Events subscribed to in atom's system can be easily
    # cleaned up with a CompositeDisposable
    @subscriptions = new CompositeDisposable

    # Register command that toggles this view
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:toggle': => @toggle()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:show': => @show()
    @subscriptions.add atom.commands.add 'atom-workspace', 'advanced-web-editor:hide': => @hide()

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
    advancedWebEditorViewState: @advancedWebEditorView.serialize()

  toggle: ->
    console.log 'AdvancedWebEditor was toggled!'

    if @modalPanel.isVisible()
      @hide()
    else
      @show()

  hide: ->
    console.log 'AdvancedWebEditor hidden'
    @modalPanel.hide()

  show: ->
    console.log 'AdvancedWebEditor shown'
    @modalPanel.show()

  closeModal: ->
    @modalPanel.close()
