# an example implementation of a data provider which shows
# the dependencies between modules in celestrium

class DependencyProvider extends celestrium.defs["DataProvider"]

  @uri: "DependencyProvider"

  getLinks: (node, nodes, callback) ->
    needs = (a, b) ->
      A = celestrium.defs[a.text]
      output =  A.needs? and b.text in _.values(A.needs)
      return output
    callback _.map(nodes, (otherNode) ->
      if needs(node, otherNode)
        return {strength: 0.8, direction: "forward"}
      if needs(otherNode, node)
        return {strength: 0.8, direction: "backward"}
      return null
    )

  getLinkedNodes: (nodes, callback) ->
    callback _.chain(nodes)
      .map((node) ->
        needs = celestrium.defs[node.text].needs
        needs ?= {}
        return _.values needs
      )
      .flatten()
      .map((text) -> {text: text})
      .value()

celestrium.register DependencyProvider
