FormView = require './form-view'
Configuration = require './configuration.coffee'

class ConfigurationFormView extends FormView

  initialize: ->
    super

    @addRow @createTitleRow("Editing Tools Configuration")
    # @addRow @createFieldRow("repoUrl", "text", Configuration.labels.repoUrl)
    @addRow @createFieldRow("fullName", "minieditor", Configuration.labels.fullName)
    @addRow @createFieldRow("email", "minieditor", Configuration.labels.email)
    # @addRow @createFieldRow("repoOwner", "text", Configuration.labels.repoOwner)
    # @addRow @createFieldRow("username", "text", Configuration.labels.username)
    # @addRow @createFieldRow("repoUsername", "text", Configuration.labels.repoUsername)
    # @addRow @createFieldRow("password", "password", Configuration.labels.password)
    @addRow @createFieldRow("cloneDir", "directory", Configuration.labels.cloneDir)
    # @addRow @createFieldRow("advancedMode", "checkbox", Configuration.labels.advancedMode)

module.exports = document.registerElement('awe-configuration-form-view', prototype: ConfigurationFormView.prototype, extends: 'div')
