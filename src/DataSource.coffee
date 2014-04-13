# you should extend this class to create your own data provider

class DataSource

  @uri: "DataSource"
  @needs:
    graphModel: "GraphModel"
    graphView: "GraphView"

  constructor: () ->
    @graphView.on "enter:node", (nodeEnter) ->
      nodeEnter.on 'click', (clickedNode) ->
        @searchAround clickedNode, (nodes, links) =>
          _.each nodes, (node) =>
            @graphModel.putNode node
          _.each links, (link) =>
            @graphModel.putLink link

  # calls callback with these arguments
  #  nodes - array of nodes, disjoint from current nodes
  #  links - array of links, with source and target as indices
  #          into original nodes + new nodes
  searchAround: (node, callback) ->

celestrium.register DataSource
