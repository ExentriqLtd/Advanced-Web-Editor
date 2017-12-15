{ TextEditor } = require 'atom'

class FormView extends HTMLElement

  initialize: () ->
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
    table.appendChild(@tableBody)

    @fields = []
    @rows = []

  addRow: (row) ->
    @tableBody.appendChild row

  createTitleRow: (title) ->
    row = document.createElement "tr"
    h1 = document.createElement "h1"
    h1.innerText = title

    titleTd = @emptyTd()
    titleTd.appendChild h1
    row.appendChild @emptyTd()
    row.appendChild titleTd

    return row

  emptyTd: () ->
    return document.createElement 'td'

  createFieldRow: (id, type, label, options) ->
    row = document.createElement("tr")
    # row.classList.add("native-key-bindings") if type != "minieditor" # workaround Atom bug
    row.appendChild @createLabel(id, label)
    row.appendChild @createField(id, type, null, options)
    row.appendChild @createProgressLabel(id) if type == "progress"
    return row

  createLabel: (id, caption, cssClass) ->
    td = document.createElement("td")
    label = document.createElement("label")
    label.innerText = caption
    label.classList.add(cssClass) if cssClass?
    label.setAttribute "for", id
    td.appendChild label
    return td

  # For type == "select", expect options as array of
  # {value: 123, text: "XXXX"}
  createField: (id, type, cssClass, options) ->
    td = document.createElement("td")
    field = document.createElement("input") if type not in ["select", "progress", "minieditor"]
    field = document.createElement("select") if type == "select"
    field = document.createElement("progress") if type == "progress"
    field = document.createElement("atom-text-editor") if type == "minieditor"

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

    if type == "select"
      # console.log "Adding options"
      options.forEach (option) ->
        # console.log "Adding option", option
        opt = document.createElement("option")
        opt.value = option
        opt.text = option
        field.appendChild opt

    if type == "progress"
      field.setAttribute "value", 0
      field.setAttribute "max", 100

    if type = "minieditor"
      field.setAttribute("mini", "mini")
      # field.tabIndex = "0"

    td.appendChild field
    console.log "Created field", field, field.id
    return td

  createProgressLabel: (id) ->
    td = document.createElement("td")
    label = document.createElement("label")
    label.id = "#{id}_label"
    label.innerText = @formatProgress(0)
    @fields.push label
    td.appendChild label
    return td

  formatProgress: (value) ->
    rounded = ((Math.round(value * 10.0)) / 10.0).toFixed(1)
    return "#{rounded}%"

  reset: ->
    @fields.forEach (x) ->
      type = x.getAttribute("type")
      x.value = "" if type in ["text","password"]
      x.checked = false if type in ["checkbox"]
      x.getModel().setText("") if x.localName == "atom-text-editor"

  setValues: (data) ->
    @reset()
    Object.keys(data).forEach (k) =>
      field = @fields.find (x) -> x.id == k
      field?.value = data[k] if field?.getAttribute("type") in ["text","password","select"]
      field?.checked = data[k] if field?.getAttribute("type") == "checkbox"
      field?.getModel().setText(data[k]) if field?.getModel && field?.localName == "atom-text-editor"

  getValues: () ->
    values = {}
    @fields.forEach (x) ->
      type = x.getAttribute("type")
      values[x.id] = x.value if type in ["text","password","select"]
      values[x.id] = (x.checked == true) if type == "checkbox"
      # console.log x, type, x.id
      values[x.id] = x.getModel().getText() if x.getModel && x.localName = "atom-text-editor"
    # console.log values
    return values

  forceTabIndex: () ->
    i = 1
    @fields.forEach (x) ->
      x.tabIndex = i++

module.exports = FormView
