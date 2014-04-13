class StaticProvider extends celestrium.defs["DataProvider"]
  @uri: "StaticProvider"
  constructor: (nodes, links) ->
    super()
    _.each nodes, (node) => @graphModel.putNode node
    _.each links, (link) => @graphModel.putLink link

  searchAround: (callback) ->
