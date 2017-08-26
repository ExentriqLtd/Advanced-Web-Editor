ButtonDecorator = require './button-decorator'
ConfigurationFormView = require './util/configuration-form-view'

module.exports =
class ConfigurationView extends ButtonDecorator
  constructor: (configuration, saveCallback, cancelCallback) ->
    @form = new ConfigurationFormView()
    @form.initialize()
    @form.setValues configuration.get() if configuration?
    buttons = [
      {label: "Save", callback: saveCallback}
      {label: "Cancel", callback: cancelCallback}
    ]

    super @form, buttons

  readConfiguration: ->
    return @form.getValues()
