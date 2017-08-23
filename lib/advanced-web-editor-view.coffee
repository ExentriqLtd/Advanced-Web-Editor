fs = require 'fs'
ConfigurationFormView = require './util/configuration-form-view'

module.exports =
class ConfigurationView
  constructor: (configuration, saveCallback, cancelCallback) ->
    # Create root element
    @element = document.createElement('div')
    @element.classList.add('advanced-web-editor')

    @form = new ConfigurationFormView()
    @form.initialize()
    @form.setValues configuration.get() if configuration?
    @element.appendChild @form
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
    return @form.getValues()
