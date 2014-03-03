class StaticProvider extends celestrium.defs["DataProvider"]

  @uri: "StaticProvider"

  constructor: (data) ->
    super()
    [@nodes, @links] = [data.nodes, data.links]
    @graph = {}
    @linkDict = {}
    _.each @links, (link) =>
      [source, target] = [link.source, link.target]
      @graph[source.text] ?= []
      @graph[source.text].push link
      @graph[target.text] ?= []
      @graph[target.text].push link
      @linkDict[@graphModel.linkHash(link)] = link
    _.each @nodes, (node) => @graphModel.putNode node
    _.each @links, (link) => @graphModel.putLink link

  searchAround: (callback) ->
    selectedNodes = @nodeSelection.getSelectedNodes()

    newNodes = _.chain(selectedNodes)
      .map((node) =>
        links = @graph[node.text]
        links ?= []
        _.map links, (link) ->
          if link.source is node
            return link.target
          else
            return link.source
      ).flatten()
      .uniq()
      .filter((node) =>
        not @graphModel.hasNode node
      ).value()

    getLink = (node1, node2) =>
      @linkDict[@graphModel.linkHash({source:node1, target:node2})]

    links = []
    _.each newNodes, (newNode) =>
      _.each @graphModel.getNodes(), (oldNode) ->
        link1 = getLink(newNode, oldNode)
        link2 = getLink(oldNode, newNode)
        links.push link1 if link1?
        links.push link2 if link2?

    _.each newNodes, (newNode1, i) ->
      _.each newNodes, (newNode2, j) ->
        return if i is j
        link = getLink(newNode1, newNode2)
        links.push link if link?

    callback(newNodes, links)

celestrium.register StaticProvider
