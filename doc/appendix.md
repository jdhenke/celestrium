## Appendix

This appendix includes the core parts of several different implementations using Celestrium.
The first is for an interface to explore a randomly generated graph.
We felt this was a very simple implementation as it doesn't require a backend and should be considered a lower bound on the cost of implementation for comparison against the following interfaces.
The three following interfaces as the three case studies as described in the Three Interface Case Studies section.

### Random Graph Interface Code

This example shows the necessary code to create the functionality for a random graph generator.
This implementation is also more thoroughly explained to illustrate the general structure of an implementation.

> NOTE: `PhoneticAlphabet` is just an array of strings which is the phonetic alphabet.

#### `main.coffee`

```coffeescript
requirejs.config {baseUrl: "/js"}

require ["Celestrium", "PhoneticAlphabet"],
(Celestrium, PhoneticAlphabet) ->

  plugins =
    "Layout":
      el: document.querySelector "body"
    "KeyListener":
      document.querySelector "body"
    "GraphModel":
      nodeHash: (node) -> node.text
      linkHash: (link) -> link.source.text + link.target.text
    "GraphView": {}
    "NodeSelection": {}
    "Sliders": {}
    "ForceSliders": {}
    "LinkDistribution": {}
    "NodeSearch":
      local: PhoneticAlphabet
    "RandomDataProvider": {}

  Celestrium.init plugins
```

This script is the entry point for code execution.

First, it configures the location where requirejs finds its modules.

Then `require` is used to load the `Celestrium` module definition and initiate the desired plugins for this interface.
`Celestrium.init` expects a dictionary with keys as the `requirejs` path to the plugin to be instantiated and values as the object to be fed as an argument to that plugin's constructor, as described in the Celestrium Implementation section.

#### `RandomDataProvider.coffee`

```coffeescript
define ["DataProvider", "PhoneticAlphabet"],
(DataProvider, PhoneticAlphabet) ->
  class RandomDataProvider extends DataProvider

    getLinks: (node, nodes, callback) ->
      callback _.map nodes, () ->
        "strength": Math.max(0, 2 * Math.random() - 1)
        "direction": _.sample [
          null,
          "forward",
          "backward",
          "bidirectional"
        ]

    getLinkedNodes: (nodes, callback) ->
      callback _.chain(PhoneticAlphabet)
        .sample(5)
        .map((word) -> {"text": word})
        .value()
```

As described in the implementation section, `getLinks` returns an array of links between `node` and `nodes`.
In this case, it's 0 half the time and randomly between [0,1] the other half.
It's directionality is also random.

`getLinkedNodes` returns all nodes linked to any node in `nodes`, which in this case is 5 random entries from the Phonetic Alphabet.

### Emails Interface Code

#### `main.coffee`

This is a standard implementation of the main entry-point to Celestrium.
In this implementation, we define an ordering for our plugins based on what we think will allow for the best usability in exploring this dataset.

```coffeescript
requirejs.config
  baseUrl: "/scripts/celestrium/core/"

  paths:
    local: "../../"

require ["Celestrium"], (Celestrium) ->

  plugins =

    Layout:
      el: document.querySelector("body")

    KeyListener:
      document.querySelector("body")

    GraphModel:
      nodeHash: (node) -> node.text
      linkHash: (link) -> link.source.text + link.target.text

    GraphView: {}
    Sliders: {}
    ForceSliders:
      pluginOrder: 2
    NodeSearch:
      pluginOrder: 1
      prefetch: "get_nodes"

    Stats:
      pluginOrder: 2
    NodeSelection: {}
    LinkDistribution:
      pluginOrder: 3
    SelectionLayer: {}
    "local/EmailDataProvider": {}

  Celestrium.init plugins, (instances) ->
    instances["GraphView"].getLinkFilter().set("threshold", 0)
```

#### `EmailDataProvider.coffee`

This is a very simple example of a DataProvider implementation that communicates with a backend server. `EmailDataProvider` hits the server with an ajax request and processes the returned data so that Celestrium can render it.

```coffeescript
define ["DataProvider"], (DataProvider) ->

  class EmailDataProvider extends DataProvider

    init: (instances) ->
      super(instances)

    getLinks: (node, nodes, callback) ->
      data =
        node: JSON.stringify(node)
        otherNodes: JSON.stringify(nodes)
      @ajax "get_edges", data, (links) ->
        callback links

    getLinkedNodes: (nodes, callback) ->
      data =
        nodes: JSON.stringify(nodes)
      @ajax "get_related_nodes", data, callback
```

### Github Collaboration Interface Code

#### `main.coffee`

```coffeescript
requirejs.config

  baseUrl: "/celestrium/core/"

  paths:
    local: "../../"

require ["Celestrium"], (Celestrium) ->
  plugins =
    Layout:
      el: document.querySelector("body")

    KeyListener:
      document.querySelector("body")

    GraphModel:
      nodeHash: (node) -> node.text
      linkHash: (link) -> link.source.text + link.target.text

    GraphView: {}

    "Sliders": {}
    "ForceSliders": {}
    "NodeSearch":
        prefetch: "get_nodes"
      "Stats": {}
      "NodeSelection": {}
      "SelectionLayer": {}
      "NodeDetails": {}
      "LinkDistribution": {}
      "LinkDistributionNormalizer": {}

    "local/GithubDataProvider": {}

  # initialize the plugins and execute a callback once done
  Celestrium.init plugins, (instances) ->

    # this allows all link strengths to be visible
    instances["GraphView"].getLinkFilter().set("threshold", 0)

```

#### `GithubDataProvider.coffee`

```coffeescript
define ["DataProvider"], (DataProvider) ->

  class GithubDataProvider extends DataProvider

    init: (instances) ->
      super(instances)


    getLinks: (node, nodes, callback) ->
      data =
        node: JSON.stringify(node)
        otherNodes: JSON.stringify(nodes)
      @ajax "get_edges", data, (arrayOfCoeffs) ->
        callback _.map arrayOfCoeffs, (coeffs, i) ->
          strength: coeffs
          base_value: coeffs

    getLinkedNodes: (nodes, callback) ->
      data =
        nodes: JSON.stringify(nodes)
      @ajax "get_related_nodes", data, callback
```

### Semantic Network Interface Code

#### `main.coffee`

```coffeescript
localStorage.clear()
requirejs.config

  # must point to the URL corresponding to the celestrium repo
  baseUrl: "/scripts/celestrium/core"
  # specifies namespace and URL path to my custom plugins
  paths: "uap": "../../uap/"

# main entry point
require ["Celestrium"], (Celestrium) ->

  # call with server's response to ping about dimensionality
  main = (response) ->

    # initialize the workspace with all the below plugins
    Celestrium.init
      # these come with celestrium
      # their arguments should be specific to this data set
      "Layout":
        "el": document.querySelector "#workspace"
        "title": "UAP"
      "KeyListener":
        document.querySelector "body"
      "GraphModel":
        "nodeHash": (node) -> node.text
        "linkHash": (link) -> link.source.text + link.target.text
      "GraphView": {}
      "Sliders": {}
      "ForceSliders": {}
      "NodeSearch":
        prefetch: "get_nodes"
      "Stats": {}
      "NodeSelection": {}
      "SelectionLayer": {}
      "NodeDetails": {}
      "LinkDistribution": {}
      # these are plugins i defined specific to this data set
      "uap/DimSlider":
        [response.min, response.max]
      "uap/ConceptProvider": {}
      "uap/CodeLinks": {}

  # ask server for range of dimensionalities
  $.ajax
    url: "get_dimensionality_bounds"
    success: main
```

#### `ConceptDataProvider.coffee`

```coffeescript
# interface to uap's semantic network
# nodes are concepts from a semantic network
# links are the relatedness of two concepts
define ["DataProvider"], (DataProvider) ->

  # minStrength is the minimum similarity
  # two nodes must have to be considered linked.
  # this is evaluated at the minimum dimensionality
  numNodes = 25

  class ConceptProvider extends DataProvider

    init: (instances) ->
      @dimSlider = instances["uap/DimSlider"]
      super(instances)

    getLinks: (node, nodes, callback) ->
      data =
        node: JSON.stringify(node)
        otherNodes: JSON.stringify(nodes)
      @ajax "get_edges", data, (arrayOfCoeffs) ->
        callback _.map arrayOfCoeffs, (coeffs, i) ->
          coeffs: coeffs

    getLinkedNodes: (nodes, callback) ->
      data =
        nodes: JSON.stringify(nodes)
        numNodes: numNodes
      @ajax "get_related_nodes", data, callback

    # initialize each link's strength before being added to the graph model
    linkFilter: (link) ->
      @dimSlider.setLinkStrength(link)
      return true
```
