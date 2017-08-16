class ConfigurationView extends HTMLElement

  initialize: ->
    @classList.add("awe-configuration")

    # panel body
    panelBody = document.createElement("div")
    panelBody.classList.add("panel-body")
    @appendChild(panelBody)

    # table
    table = document.createElement("table")
    panelBody.appendChild(table)

    # table body
    @tableBody = document.createElement("tbody")

    @fields = []
    @rows = []
    # ["repoUrl", "username", "password", "cloneDir", "advancedMode"]
    @rows.push @createFieldRow("repoUrl", "text", "Project Clone URL")
    @rows.push @createFieldRow("username", "text", "Username")
    @rows.push @createFieldRow("password", "password", "Password")
    @rows.push @createFieldRow("cloneDir", "directory", "Clone Directory")
    @rows.push @createFieldRow("advancedMode", "checkbox", "Advanced Mode")

    @rows.forEach (f) => @tableBody.appendChild f

    table.appendChild(@tableBody)

  createFieldRow: (id, type, label) ->
    row = document.createElement("tr")
    row.appendChild @createLabel(id, label)
    row.appendChild @createField(id, type)
    return row

  createLabel: (id, caption, cssClass) ->
    td = document.createElement("td")
    label = document.createElement("label")
    label.innerText = caption
    label.classList.add(cssClass) if cssClass?
    label.setAttribute "for", id
    td.appendChild label
    return td

  createField: (id, type, cssClass) ->
    td = document.createElement("td")
    field = document.createElement("input")
    field.id = id

    @fields.push field

    field.setAttribute("type", if type != "directory" then type else "text")
    field.classList.add(cssClass) if cssClass?

    if type == "directory"
      field.setAttribute "readonly", true
      field.addEventListener "click", () ->
        atom.pickFolder (folder) ->
          if(folder)
            field.value = folder

    td.appendChild field
    # console.log "Created field", field, field.id
    return td

  destroy: ->
    @remove() if @parentNode

  readValues: ->
    return @fields.map (x) -> x.value

  setValues: (configuration) ->
    # console.log "ConfigurationView::setValues", configuration
    Object.keys(configuration).forEach (k) =>
      # console.log "Key: ", k, @fields
      field = @fields.find (x) -> x.id == k
      field?.value = configuration[k] if field?.getAttribute("type") in ["text","password"]
      field?.checked = configuration[k] if field?.getAttribute("type") == "checkbox"

  getValues: () ->
    values = {}
    @fields.forEach (x) ->
      type = x.getAttribute("type")
      values[x.id] = x.value if type in ["text","password"]
      values[x.id] = (x.checked == true) if type == "checkbox"
    return values

module.exports = document.registerElement('awe-configuration-view', prototype: ConfigurationView.prototype, extends: 'div')
