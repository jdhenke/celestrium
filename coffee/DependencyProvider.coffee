# an example implementation of a data provider which shows
# the dependencies between modules in celestrium

class DependencyProvider extends celestrium.defs["DataProvider"]

  @uri: "DependencyProvider"

  searchAround: (callback) ->
    # get list of unique, related nodes disjoin from current nodes
    nodes = @graphModel.getNodes()
    newNodes = _.chain(@nodeSelection.getSelectedNodes())
      .map((node) ->
        needs = celestrium.defs[node.text].needs
        needs ?= {}
        return _.values needs
      )
      .flatten()
      .filter((text) =>
        return not @graphModel.get("nodeSet")[text]
      )
      .uniq()
      .map((text) -> {text: text})
      .value()

    # get links between
    #  - all current nodes and new nodes
    #  - all new nodes and eachother
    needs = (a, b) ->
      A = celestrium.defs[a.text]
      output =  A.needs? and b.text in _.values(A.needs)
      return output
    links = []
    _.each nodes, (oldNode, i) ->
      _.each newNodes, (newNode, j) ->
        if needs(oldNode, newNode)
          links.push
            source: i
            target: nodes.length + j
            strength: 0.8
            direction: "forward"
        else if needs(newNode, oldNode)
          links.push
            source: i
            target: nodes.length + j
            strength: 0.8
            direction: "backward"
    _.each newNodes, (node1, i) ->
      _.each newNodes, (node2, j) ->
        return if i is j
        if needs(node1, node2)
          links.push
            source: nodes.length + i
            target: nodes.length + j
            strength: 0.8
            direction: "forward"
    callback(newNodes, links)

celestrium.register DependencyProvider
