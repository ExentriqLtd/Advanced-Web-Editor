FormView = require './form-view'
Configuration = require './configuration.coffee'

class ConfigurationFormView extends FormView

  initialize: ->
    super

    @addRow @createFieldRow("repoUrl", "text", Configuration.labels.repoUrl)
    @addRow @createFieldRow("fullName", "text", Configuration.labels.fullName)
    @addRow @createFieldRow("email", "text", Configuration.labels.email)
    @addRow @createFieldRow("repoOwner", "text", Configuration.labels.repoOwner)
    @addRow @createFieldRow("username", "text", Configuration.labels.username)
    @addRow @createFieldRow("password", "password", Configuration.labels.password)
    @addRow @createFieldRow("cloneDir", "directory", Configuration.labels.cloneDir)
    @addRow @createFieldRow("advancedMode", "checkbox", Configuration.labels.advancedMode)

module.exports = document.registerElement('awe-configuration-form-view', prototype: ConfigurationFormView.prototype, extends: 'div')