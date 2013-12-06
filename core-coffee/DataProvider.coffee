# you should extend this class to create your own data provider
define [], () ->

  class DataProvider

    init: (instances) ->
      @NodeSelection = instances["NodeSelection"]
      @graphModel = instances["GraphModel"]

      instances["KeyListener"].on "down:16:187", () =>
        @addRelatedNodes()

      @graphModel.on "add:node", (node) =>
        nodes = @graphModel.getNodes()
        @getLinks node, nodes, (links) =>
          _.each links, (link, i) =>
            link.source = node
            link.target = nodes[i]
            @graphModel.putLink link if @linkFilter link

      ContextMenu = instances["ContextMenu"]
      ContextMenu.addMenuOption "Expand Nodes", @addRelatedNodes, @

    # should call callback with a respective array of links from node to nodes
    # source and target will automatically be assigned
    addRelatedNodes: ->
      @getLinkedNodes @NodeSelection.getSelectedNodes(), (nodes) =>
          _.each nodes, (node) =>
            @graphModel.putNode node if @nodeFilter node

    getLinks: (node, nodes, callback) ->
      throw "must implement getLinks for your data provider"

    # should call callback with an array of nodes linked to any of nodes
    getLinkedNodes: (nodes, callback) ->
      throw "must implement getLinkedNodes for your data provider"

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
