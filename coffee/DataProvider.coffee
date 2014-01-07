# you should extend this class to create your own data provider

class DataProvider

  @uri: "DataProvider"
  @needs:
    graphModel: "GraphModel"
    keyListener: "KeyListener"
    nodeSelection: "NodeSelection"

  constructor: () ->
    @keyListener.on "down:16:187", () =>
      @getLinkedNodes @nodeSelection.getSelectedNodes(),
      (nodes) =>
        _.each nodes, (node) =>
          @graphModel.putNode node if @nodeFilter node
    @graphModel.on "add:node", (node) =>
      nodes = @graphModel.getNodes()
      @getLinks node, nodes, (links) =>
        _.each links, (link, i) =>
          if link == null
            return
          link.source = node
          link.target = nodes[i]
          @graphModel.putLink link if @linkFilter link

  # should call callback with a respective array of links from node to nodes
  # source and target will automatically be assigned
  getLinks: (node, nodes, callback) ->
    throw new Error("must implement getLinks for your data provider")

  # should call callback with an array of nodes linked to any of nodes
  getLinkedNodes: (nodes, callback) ->
    throw new Error("must implement getLinkedNodes for your data provider")

  # called on each node - only adds the node if returns true
  nodeFilter: -> true

  # called on each link - only adds the link if returns true
  linkFilter: -> true

  # makes an ajax request to url with data and calls callback with response
  ajax: (url, data, callback) ->
    $.ajax
      url: url
      data: data
      success: callback

celestrium.register DataProvider
