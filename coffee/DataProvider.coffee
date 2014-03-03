# you should extend this class to create your own data provider

class DataProvider

  @uri: "DataProvider"
  @needs:
    graphModel: "GraphModel"
    keyListener: "KeyListener"
    nodeSelection: "NodeSelection"

  constructor: () ->
    @keyListener.on "down:16:187", () =>
      @searchAround (nodes, links) =>
        _.each nodes, (node) =>
          @graphModel.putNode node
        _.each links, (link) =>
          @graphModel.putLink link

  # calls callback with these arguments
  #  nodes - array of nodes, disjoint from current nodes
  #  links - array of links, with source and target as indices
  #          into original nodes + new nodes
  searchAround: (callback) ->

celestrium.register DataProvider
