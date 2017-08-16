fs = require 'fs'
ConfigurationView = require './util/configuration-view'

module.exports =
class AdvancedWebEditorView
  constructor: (configuration, saveCallback, cancelCallback) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('advanced-web-editor')

    @configurationView = new ConfigurationView()
    @configurationView.initialize()
    @configurationView.setValues configuration.get() if configuration?
    @element.appendChild @configurationView
    @element.appendChild document.createElement('hr')

    buttonsDiv = document.createElement('div')
    buttonsDiv.classList.add("awe-buttons")
    buttonsDiv.appendChild @createButton("Save", saveCallback)
    buttonsDiv.appendChild @createButton("Cancel", cancelCallback)

    @element.appendChild buttonsDiv

  createButton: (label, callback) ->
    @button = document.createElement('input')
    @button.setAttribute("type", "button")
    @button.classList.add("awe-button")
    @button.value = label
    @button.addEventListener "click", callback if callback?
    return @button

  # Returns an object that can be retrieved when package is activated
  serialize: ->

  # Tear down any state and detach
  destroy: ->
    @element.remove()

  getElement: ->
    @element

  readConfiguration: ->
    return @configurationView.getValues()
