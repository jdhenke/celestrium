# you should extend this class to create your own data provider

class DataSource

  @uri: "DataSource"
  @needs:
    graph: "Graph"

  constructor: () ->
    @graph.on "enter:node", (nodeEnter) =>
      # handle selecting and deselecting nodes
      clickSemaphore = 0
      @graph.on "enter:node", (nodeEnterSelection) =>
        nodeEnterSelection.on("click", (datum, index) =>
          # ignore drag
          return  if d3.event.defaultPrevented
          datum.fixed = true
          clickSemaphore += 1
          savedClickSemaphore = clickSemaphore
          setTimeout (=>
            if clickSemaphore is savedClickSemaphore
              _.each @graph.nodes, (node) ->
                node.fixed = false
              datum.x = $(window).width() / 2
              datum.y = $(window).height() / 2
              datum.fixed = true
            else
              # increment so second click isn't registered as a click
              clickSemaphore += 1
              datum.fixed = false
          ), 250
        ).on "dblclick", (datum, index) =>
          # TODO: do search around
          @searchAround datum, (nodes, links) =>
            _.each nodes, (node) => @graph.nodes.push(node)
            _.each links, (link) => @graph.links.push(link)

  # calls callback with these arguments
  #  nodes - array of nodes, disjoint from current nodes
  #  links - array of links, with source and target as indices
  #          into original nodes + new nodes
  searchAround: (node, callback) ->

celestrium.register DataSource
