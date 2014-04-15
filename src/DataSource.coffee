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
              @centerNode(datum)
            else
              # increment so second click isn't registered as a click
              clickSemaphore += 1
          ), 250
        ).on "dblclick", (datum, index) =>
          @centerNode(datum)
          @addNodes datum, (nodes) =>
            _.each nodes, (node) =>
              present = _.some @graph.nodes, (currentNode) ->
                node.text == currentNode.text
              if not present
                @graph.nodes.push(node)
    @graph.nodes.on "add", (node) =>
      @addLinks node, (links) =>
        _.each links, (link, i) =>
          link.source = i
          link.target = node
          @graph.links.push(link)

  centerNode: (centerNode) ->
    _.each @graph.nodes, (node) ->
      node.fixed = false
    centerNode.x = $(window).width() / 2
    centerNode.y = $(window).height() / 2
    centerNode.fixed = true
    @graph.getNodeSelection().classed "centered", (n) ->
      n is centerNode

celestrium.register DataSource
