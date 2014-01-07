# provides an input box which can add nodes to the graph

class NodeSearch extends Backbone.View

  @uri: "NodeSearch"
  @needs:
    graphModel: "GraphModel"
    keyListener: "KeyListener"
    layout: "Layout"

  events:
    "typeahead:selected input": "addNode"

  constructor: (@options) ->
    super()
    @listenTo @keyListener, "down:191", (e) =>
      @$("input").focus()
      e.preventDefault()
    @render()
    @layout.addPlugin @el, @options.pluginOrder, 'Search'

  render: ->
    $container = $("<div />").addClass("node-search-container")
    $input = $("<input type=\"text\" placeholder=\"Node Search...\">")
      .addClass("node-search-input")
    $container.append $input
    @$el.append $container
    $input.typeahead
      prefetch: @options.prefetch
      local: @options.local
      name: "nodes"
      limit: 100
    return this

  addNode: (e, datum) ->
    newNode = text: datum.value
    h = @graphModel.get("nodeHash")
    newNodeHash = h(newNode)
    nodeWithHashExists = _.some @graphModel.get("nodes"), (node) ->
      h(node) is newNodeHash
    @graphModel.putNode newNode unless nodeWithHashExists
    $(e.target).blur()

celestrium.register NodeSearch
