Celestrium
==========

Sharon Hao, Justin Helbert, Joe Henke

MIT 6.885

Professor Madden

## Abstract

Celestrium is a collection of requirejs modules which enables developers to easily create interfaces to visualize and explore large graph based datasets.
It is designed to be database agnostic and minimize the activation energy required by developers, easily interfacing with JSON endpoints to populate the visualization.
This paper discusses how and why Celestrium's plugin architecture was designed the way it is and argues it could be useful in other contexts.
Additionally, it explains implementations of several interfaces which used Celestrium, each for different data sets, and compares the necessary lines of code, showing Celestrium to be broadly useful without requiring much additional effort.

## Intro

Celestrium is a frontend architecture for the web to visualize graphs.
Prior to Celestrium, several javascript graph visualization frameworks existed.
They and their differences with Celestrium are listed here.

[**Canviz**](http://stackoverflow.com/a/5715325) can render standard `.dot` files as a graph, which Celestrium cannot do.
However, the resulting visualization is static - the nodes cannot be moved.
In Celestrium, nodes can be clicked, selected and dragged, continuously altering the layout of the graph.

[**Javascript InfoVis Toolkit**](http://philogb.github.io/jit/index.html) and [**VivaGraphJS**](https://github.com/anvaka/VivaGraphJS) are more dynamic and can detect user interaction with nodes, for example.
However, they are only responsible for rendering the graph's layout.
Ultimately, what separates Celestrium from VivaGraphJS and all other libraries is it has extra plug-and-play features builtin such as:

* Being able to manipulate and view distributions of link strengths
* Running graph analysis algorithms on the visible subgraph
* Providing an API to easily integrate with JSON server endpoints

In a sense, Celestrium takes graph visualization platforms further by providing default, but replaceable, implementations of common functionalities to make creating graph visualizations easier.
Celestrium is intended for the case where a user wants to visually analyze a graph database which is too big to understand all at once and so must be investigated from a particular node or nodes outwards, bottom up.

## Example Interface

> Should concisely explain the directory structure of a simple application
> as well as what the resulting interface looks like and how to use it

## Implementation

### Plugin Architecture

Celestrium is implemented as a collection of requirejs plugins, so the design pattern which dictates the interaction between these plugins is critical.
Celestrium leverages `requirejs` to provide access to plugin *definitions*.
Then, building on top of that, Celestrium uses a custom infrastructure to provide access to the *instance* of each plugin.
The difference may or may not be obvious, but it is important in understanding Celestrium's design.

- **Definitions**, conceptually, provide the *ability* to create a certain type of object.
- **Instances** - are the *instantiated objects* themselves.

To make this concrete, consider the GraphModel plugin.
The *definition* is the class definition in Coffeescript, but an *instance* is a GraphModel object.
This may seem trivial, but requirejs only provides the definitions, not the instances, which is an issue because plugins almost always need access to the *instance* of another plugin and more specifically, they need access to the *same* instance.

For example, if the GraphView instance was listening to a different GraphModel instance than the DataProvider instance, (which adds nodes and links to it,) the GraphView would never receive that information because it's listening to a completely different object.
This seems to suggest a singleton pattern, where each class automatically creates an instance of itself and attaches it to the class definition.
However, plugins often need parameters in their constructor that must be specified by the developer somehow i.e. the DOM element in which to house the workspace.
Thus plugin definitions can't automatically instantiate themselves without providing an entry for custom parameters.

Celestrium addresses these needs by separating the entry of parameters and instances of other plugins into these separate places:

* A plugin's **constructor** accepts arguments from the developer.
* A plugin's **init** function accepts a dictionary of instances of other plugins.

The code which facilitates this is actually very concise and is shown here. This is out of a special module called `Celestrium`, which has one function, `init`:

```coffeescript
init: (pluginsDict, callback) ->
  pluginPaths = _.keys(pluginsDict)
  instances = {}
  require pluginPaths, (plugins...) ->
    _.each plugins, (plugin, i) ->
      options = pluginsDict[pluginPaths[i]]
      instance = new plugin(options)
      instance.init instances
      instances[pluginPaths[i]] = instance
    callback(instances) if callback?
```

So, `Celestrium.init` accepts a dictionary, `pluginsDict`, with keys being requirejs paths to the plugins to be instantiated and the values being the arguments to the constructor.

So iterating through `pluginsDict`, a list of plugin instances, `instances`, is maintained, and each plugin is

* instantiated with it's given arguments
* `init`ed with `instances` as the argument
* added to `instances` itself, so later plugins may access it.

An issue here is that no circular dependencies may exist.
It is unclear if maintaining this invariant is good design anyway or a limitation of this approach.

An alternative could be to perform two passes.
On the first, each plugin is created and added to the `instances` dictionary.
Then on the second pass, each instance would be `init`ed with the dictionary of every instance, even the last one.
This was not chosen as it then exposes plugins which have not yet been `init`ed to be used by other plugins.
So, the current specification dictates that if plugin `A` needs an instance of plugin `B`, `B` should appear before `A` in the dictionary.

Ultimately, this architecture formalizes the method by which instances of plugins are accessed by other plugins and allows developers to pass arguments to the necessary plugins.
In fact, we feel this is a good design approach for *any* interface which has distinct components, because it removes the boilerplate of constructing each plugin manually and providing it the required instances of other plugins.


### Plugin Descriptions

ContextMenu
* a circular popup menu (toggled by pressing ‘m’) with actions concerning selected nodes
* developers can add new options with `addMenuOption: (menuText, itemFunction, that)`

DataProvider
* abstract class that developer extends to connect Celestrium to their data
* developers specify `getLinks(node, nodes, callback)` and `getLinkedNodes(nodes, callback)` functions

GraphModel
* Core underlying model of the graph
* contains getter and setter methods for Nodes and Links

GraphView
* renders graph with data from GraphModel plugin using d3 libraries
* provides update function to re-render the graph when it changes

KeyListener
* allows hotkeys to fire events from any plugin
* built-in hotkeys include ctrl+A to select all nodes, ESC to deselect all nodes, 'm' to toggle the ContextMenu

Layout
* Manages overall UI layout of page
* provides functions to add DOM elements to containers in parts of the screen

LinkDistribution
* provides a variably smoothed PDF of the distribution of link strengths.
* A slider on the PDF filters links, only weights above that threshold visible on the graph.

NodeSearch
* Provides an input box to add a single node to the graph
* developer supplies a method in the constructor to get a list of all nodes in the graph

NodeSelection
* allows nodes to be selected or unselected
* provides functions to access the state of the selected nodes

Sliders
* provides an interface to add sliders to the ui
* function to add a new slider: `addSlider(label, initialValue, onChange)`

### Modeling a Graph

Moving from the plugin architecture to a single plugin, the GraphModel plugin, this section discusses how Celestrium models a graph.

d3's force directed layout is the what currently renders the actual graph onscreen, so any deviation from d3's graph representation would require the data to be put into that format anyway.
So, it seemed optimal, practically speaking, to use d3's representation, but it was not attempted to optimize for other uses cases.
This may be worth investigating if alternative layout methods are used.

d3 uses an array of javascript objects to represent the nodes.
Links are stored as an array of javascript objects with `source` and `target` attributes which are the actual node objects themselves.

> TODO: scalability/bottleneck analysis

### Interfacing with the Backend

Now that Celestrium can internally represent a graph, it must interface with the source of the data.
To do so, Celestrium provides DataProvider.
DataProvider is an abstract class definition which need only be extended to include the functionality to connect to the server in order to fulfill the following specification:

#### `getLinks(node, nodes, callback)`

* `node` is a single node in the graph
* `nodes` is a list of nodes in the graph
* `callback` is a function which should be called with an array of links, `A`, st. `A[i]` is the link from `node` to `nodes[i]`.
  * A link should be a javascript object with a `strength` attribute in `[0,1]` and can optionally have a `direction` attribute in `{forward, backward, bidrectional}` indicating the a directed link.

#### `getLinkedNodes(nodes, callback)`

* `nodes` is a an array of nodes
* `callback` is a function which should be called with an array of `nodes` which are linked to any node in `nodes`.

Note that both of these functions accept existing nodes as arguments - so where does the first node come from?
A function such as `getAllNodes` is computationally infeasible for some datasets, so to not limit Celestrium to data sets which can be completely enumerated, it was left out of the DataProvider specification.
For data sets that can accomplish this, the NodeSearch plugin allows lookup of a node by name.
For data sets that cannot accomplish this, it is left to the developer to provide some form of random access to its nodes.

## Examples

*It's hard to think about thinking without thinking about thinking about something.*

In this spirit, this section provides concrete examples of using Celestrium.
The first is an interface which has no backend - it simply produces random links between nodes named after the Phonetic Alphabet.
This random interface is then used as a baseline in comparison to implementations of real data sets.
Because some data sets generate their graphs differently i.e. sparse matrices vs. redirecting to a REST API vs. static data, only the main script and data provider scripts are compared, however other scripts which were necessary for each interface to function are described in each section for reference.

### Example Interfaces

#### Random

This example shows the necessary code to create the functionality for a random graph generator.
This implementation is also more thoroughly explained to illustrate the general structure of an implementation.

> NOTE: `PhoneticAlphabet` is just an array of strings which is the phonetic alphabet.

##### `main.coffee`

```coffeescript
requirejs.config
  baseUrl: "/celestrium/core/"
  paths:
    local: "../../"

require ["Celestrium", "local/PhoneticAlphabet"],
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
    "local/RandomDataProvider": {}

  Celestrium.init plugins
```

This is the entry point for code execution.

The first lines configure different requirejs paths.

* `baseUrl` should be the path to the compiled output of Celestrium's `core-coffee` directory relative to the page it is included on.
* `local` specifies the path to the compiled output of plugins that were created specifically for this example and are not part of Celestrium.
This path is relative to `baseUrl`.

Then `require` is used to load the `Celestrium` module definition and initiate the desired plugins for this interface.
`Celestrium.init` expects a dictionary with keys as the `requirejs` path to the plugin to be instantiated and values as the object to be fed as an argument to that plugin's constructor, as described in the Implementation Section.

##### `random.coffee`

```coffeescript
define ["DataProvider", "local/PhoneticAlphabet"],
(DataProvider, PhoneticAlphabet) ->
  class RandomDataProvider extends DataProvider
    getLinks: (node, nodes, callback) ->
      callback _.map nodes, () ->
        "strength": Math.max(0, (Math.random() - 0.5) * 2)
        "direction": _.sample [null, "forward", "backward", "bidirectional"]
    getLinkedNodes: (nodes, callback) ->
      callback _.chain(PhoneticAlphabet)
        .sample(5)
        .map (word) ->
          "text": word
        .value()
```

As described in the implementation section, `getLinks` returns an array of links between `node` and `nodes`.
In this case, it's 0 half the time and randomly between [0,1] the other half.
It's directionality is also random.

`getLinkedNodes` returns all nodes linked to any node in `nodes`, which in this case is 5 random entries from the Phonetic Alphabet.

And that's it! The resulting interface looks like this:

> TODO: Picture

#### Emails

> TODO: Picture

##### `main.coffee`
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

The most unique thing about the emails dataset is that emails have directions. For this reason, we developed Celestrium to support directed edges. We can see that between many pairs of users, the communication is one-sided many times. Celestrium supports directed edges, so it is very simple for a developer to provide 'directed-ness' in their graphs.

In implementing this, first a python script was written to clean raw data into json for the server to read. The server then digests all the emails and organizes them into a hashtable for easy access.

##### Future Work
Currently, this proof-of-concept is static, but in the future, it would be neat to see it grow and change dynamically. There is more work to be done on the back end in terms of speed. When adding nodes to the graph, it is very easy to have sudden large increases in data when we land on a user that has a high email frequency. At these times, Celestrium can be seen to be slightly laggy.

#### Github Collaboration

The Github dataset shows collaboration between users on Github; the higher the link strength between 2 users, the more public repos they have collaborated on.
First a python script was written to scrape the Github API and collect data into a JSON format (github_data.txt).
I found it pretty straightforward to implement the GithubProvider class (code below) to connect this data to Celestrium, especially with the example implementations serving as guidance.


![image](https://f.cloud.github.com/assets/774269/1699263/f6d3cd38-5f8b-11e3-990c-15a56594ea29.png)



Looking at the distribution of collaborations, there were many relationships with few repos collaborated on), with some outliers of a very high number of repos collaborated on.
This distribution inspired a LinkDistributionNormalizer plugin, where link strengths could be transformed linearly, logarithmically, or into percentiles to best fit the distribution of the data.


#### GithubProvider

```python
import json
class GithubProvider(object):
  def __init__(self):
    f = open('github_data.txt','rb')
    f.readline()
    f.readline()
    self.data = json.loads(f.readline())
  def get_nodes(self):
    return self.data.keys()

  def get_edges(self, node, otherNodes):
    result = []
    for n2 in otherNodes:
      value = self.data[node["text"]].get(n2["text"])
      if value is None:
        value = 0
      result.append(value)
    return result

  def get_related_nodes(self, nodes):
    newNodesSet = set()
    for node in nodes:
      relatedNodes = self.data[node['text']].keys()
      i = 0
      while i < len(relatedNodes):
        relatedNode = relatedNodes[i]
        newNodesSet.add(relatedNode)
        i += 1
    return [{"text": node} for node in newNodesSet]
```

##### main.coffee

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


#### DataProvider Implementation
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


#### Future Work
The goal of this dataset is to show collaboration relationships on Github.  However, only publicly available data could be used, which restricts this to public repos.
In addition, the measure of link strength is arbitrary; I used the number of repos they collaborated on.  But should collaboration on a project with a few other people be counted the same as collaboration on a project with hundreds of other users?
The metric for 'collaboration strength' could certainly be improved on.

Future work would also include connecting the Celestrium DataProvider endpoints to query the live Github API, not needing to download a static version of data.

#### Semantic Networks

The third data set that we built an interface for using Celestrium was a semantic network.
More specifically, it was showing the results of performing **inference** over a semantic network.
More on this later.
Nodes represented every day concepts and the links showed closely they were related.

##### Example of Semantic Network Interface

![image](https://f.cloud.github.com/assets/1418690/1689464/df3411e8-5e22-11e3-8477-683173eb9d24.png)

##### Main Script
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

##### `DataProvider` Implementation

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

The most interesting part of this implementation is that `ConceptProvider` doesn't define a link's strength, only a `coeffs` parameter, then it uses `DimSlider`'s `setLinkString` function as a filter on the link.
This because the link strength's are actually a function of a polynomial in value of the **dimensionality** of the inference process, whose value is maintained in `DimSlider`.
So on the server, each link's polynomial is constructed rather than a single value, the coefficients sent to `DataProvider`, then `DimSlider` uses the current value of the "Dimensionality Slider" in the interface (see the example picture) to actually define the link's strength numerically.

Firstly, Celestrium's flexibility in defining the strength of a link was critical in creating this interface.
Additionally, this extra slider inspired the creation of the `Sliders` plugin, and allows this "Dimensionality Slider" to integrate seemlessly into the UI next to the other sliders.

Future work in this interface is to include different types of nodes, which is something that Celestrium currently doesn't prohibit, but doesn't provide express functionality for, and so perhaps a next step is to provide functionality that supports have distinct types of nodes.
More details of the specific needs of this dataset should be investigated before deciding on the specific features this would entail.


### Implementation Cost Comparisons

> TODO:
> * compare the each implementation's main and data provider wrt. lines of code
> * graphs would be good

## Future Work

Now that we've seen what Celestrium can do, it is worth detailing it's limitations and ideas for new functionality, the subjects of the following sections.
Future contributors to Celestrium are encouraged to address these topics.

###  Current Limitations

> These are limitations of the current implementations.
> Reducing these limitations is an easy way to get at future work.
> I leave *new* features to @haosharon in the next section.

Celestrium's design and implementation are certainly not without fault.
Because Celestrium's efficacy is based on how easy it is for developers to use, issues of various scopes come into play.
In an effort to explain the full spectrum, we now detail these issues progressing from the purely logistical to the more technical.

#### Infrastructure

While not as intellectually stimulating as other problems, Celestrium's infrastructure could perhaps be improved in the following ways.

Firstly, Celestrium is written primarily in Coffeescript, which compiles to Javascript.
Because of this, any developer using Celestrium must bring the tools to do this compilation into their project when they might not necessarily want or be able to.
Looking into using requirejs's optimization tool on the compiled output, Celestrium could potentially release a minified, single javascript file, making it much easier to simply put in a project.

Additionally, Celestrium uses Less, which compiles to CSS. Currently, Celestrium avoids the need to compile its less files but at the cost of users of celestrium needing to load the Less compiler onto any webpage using Celestrium.
A similar, compiled version of the CSS should be made available for Celestrium as well.

#### Code Organization

Moving into how Celestrium organizes its modules, several things could be improved.

As mentinoed previously, circular dependencies amongst plugins are not allowed.
The only drawback as it stands is that plugins must be specified according the their partial ordering of depedencies in calling `Celestrium.init`.
It remains to be seen if there is a good use case which would merit this or if there is a complete argument against circular dependencies.
Either allowing circular dependencies or providing a more thorough argument against them would at least clarify the appropriateness of this decision.

Additionally, the Layout plugin, while convenenient, is not as configurable as it could perhaps be.
While this isn't problematic in isolation, it is problematic that many of the other plugins rely on using Layout, because not wanting to use Layout then implies one cannot use any plugins which depends on it.
Making Layout more configurable and/or removing other plugins' dependence on it would certainly make Celestrium more modular.

#### Scalability

How large of a graph can interfaces created by Celestrium handle?
This question is open to interpretation, so first some framing is in order.

Firstly, we consider the scalability of the backend database a separate issue.
Celestrium is an entirely frontend library, so the specifics of the database performance certainly affect its use in practice, but it is not fundamentally part of Celestrium and so is not a good metric by which to judge Celestrium's performance.

Therefore, we will focus on the performance of the frontend.
This was done by measuring certain metrics for rendering different numbers of nodes and links, all populated entirely within the frontend.
Tests were performed on a 15" MacBook Pro with Retina Display, 2.6 GHz Intel Core i7 with 8 GB 1600 MHz DDR3 RAM using Goolge Chrome 31.0.1650.57.
Specifically, nine different tests were conducted where the number of nodes and links were from {1000, 2500, 5000}.
Then the following metrics were evaluated and tabulated.

* **Memory Usage** - The amount of memory used by the tab in Chrome
* **Time to Populate the Graph** - The amount of time it took to add the specified number of nodes and links to the graph.
* **Responsiveness of the Visualization** - Once the graph was completely populated, d3's force directed layouts iterates and on each **tick**, the graph updates the location of the nodes and links. To measure the responsiveness, the amount of time between ticks for the first ten seconds of the rendering was averaged.

Before going into the details of the results, it is worth noting that while the interface can handle these sizes of graphs, it is not a typical use case.
The purpose of these interfaces is for a human to explore these graphs and a human would have a hard time understanding a graph of even 1000 nodes and links.
Testing on a more reasonable scale i.e. 100 nodes and 1000 links yielded very good performance.
We found ~24 ms/tick which equates to ~40 updates per second, which is high enough to produce very fluid rendering of the graph to the user.
The memory usage was negligble and it took less than one second to populate the graph.
In summary, at scales a human could understand, Celestrium has been found to perform very well.

The purpose of explaining the following metrics, then, is to understand the limits of Celestrium's interface, human capabilities aside.
These limitations are worth nothing and improving because they could help improve performance on slower machines which may have trouble even on more reasonably sized graphs.
Additionally, it is impossible to rule out a use case where these sized graphs are actually necessary to render.
With that in mind, let's start with the memory used in each test case.

##### Memory Usage

The amount of memory used by the tab in chrome according to Chrome's Task Manager was recorded and the following results were found.

![image](https://f.cloud.github.com/assets/1418690/1689050/6139b0ec-5e16-11e3-9221-b234726e33f4.png)

To summarize, the amount of memory certainly scales with both links and nodes, but it seems to grow much more with the number of nodes.
The absolute scale of these numbers is well within the acceptable range of memory usage.
For reference, a tab with Gmail open was using 170 MB, putting the highest memory used by Celestrium at less than 65% of Gmail.

##### Time to Populate the Graph

Taking the time to simply populate the graph seemed to result in more dubious results for Celestrium.

To explain the following three charts, the first shows just the time it took to add the nodes to the graph for each test.
The second shows just the time it took to add the links to the graph.
The third then shows the total time, which is the sum of the first two.

![image](https://f.cloud.github.com/assets/1418690/1689134/a544cf72-5e18-11e3-987e-a1910a7a5836.png)

A few things are notable here.

The first is the general range of the results. The fastest test took approximately 6 seconds while the slowest took 4 **minutes**.

The second is that the time to add a certain number of nodes was irrespective of the number of links, while the opposite is not true and the reason for this is perhaps somewhat subtle - the nodes were always added first.
Link objects must reference the actual node objects they are linking, so the nodes must be created first.
The number of links added will never affect the time to load the nodes because it occurs after the noads are loaded.
However, it is somewhat unclear why the number of nodes affects the time to add a link.
We hypothesize that this is due to the overlap in the process of adding the links and the events still being fired from adding the nodes.

And lastly, the performance in loading the graph seems to follow the results of memory usage in that the number of nodes seems to have a greater impact on the time than the number of links.

How could this be improved?
Perhaps the fundamental issue is that nodes and links must be added individually rather than all at once.
This design choice was made to more easily communicate with the backend about updating the state of the graph.
In particular, when adding a node to the graph, the only links that must be fetched to keep the grpah current are between that node and all the nodes currently present.
If more than one node is added a time, the links between each pair of nodes within that new group must now also be considered, greatly increasing the complexity the developer must deal with.
However, if high performance for larger graphs and/or slower machines is required, we feel this is the largest bottleneck.

##### Visualization Responsiveness

The last metric to consider is how quickly the force directed layout updates itself.

It is worth mentioning the algorithm that d3 implements is the [Barnes-Hut approximation](http://en.wikipedia.org/wiki/Barnes%E2%80%93Hut_simulation) which provides an asymptotic runtime of `O(n*log(n))` for `n` nodes, as opposed to a naive implementation's `O(n^2))`.

Additionally, the rendering speed is improved if the visualization is zoomed out and worsened when zoomed in.
For these tests, the default zoom level was used for uniformity.

The following metrics were found by, once the graph was completely loaded, averaging the time between updates of the layout for the first ten seconds of the simulation.
Here is what was found:

![image](https://f.cloud.github.com/assets/1418690/1689232/a233a468-5e1b-11e3-9801-196c8c156c91.png)

First, it seems there is a fair amount of variability, as the results go from 1785 ms for 2500 nodes and links to 841 ms when the number of links *increases* to 5000.
A possible reason for this is that, due to the large number of nodes, some nodes were not always visible on the screen, perhaps reducing the browser's rendering computation.
Perhaps in the case with 2500 nodes and 5000 links, more nodes than usual were not visible, speeding up the runtime of those iterations.

To explain the >10000 entry, using 5000 nodes and links resulted in the layout never completing it's second iteration in the first ten seconds.

In summary, it seems Celestrium's interface can definitely become unusable when scaled up these sized graphs.
To overcome this, one could leverage the effects of zooming and when slow layout iterations are detected, zoom out.
Additionally, a force directed layout aproach may fundamentally not be feasable at this scale, so a one time static layout algorithm may be necessary at this scale.
Or, one could run the layout internally without updating the UI, then simply render the final result of the layout process at the end.
Again, because humans most likely would not be able to make sense of so much data, making this interface usable at this scale may not be a priority, but we suggest at least detecting when the layout iterations become slow and handling it accordingly so the user is not left simply staring at a faltering visualization.


### General Future Work

> @haosharon, see all the issues we've discussed
>
> Additionally, making Celestrium able to read **and write** to the DB would be a whole other ball game.
>
> related to infrastructure, declare v1.0.0 pursuant to [semantic versioning](http://semver.org/).
> this is incredibly practical for developers depending on this.
>
> not interesting but worth mentioning unit testing and continuous integration

Celestrium is currently in a v1.0 state. For the future, there are many features we'd like to add.

* **Minimap** when a user explores a very large dataset, it is sometimes easy to get lost in the low-level details. We'd like to provide a minimap so users can always have a sense of the entire graph.

* **Clustering** Celestrium currently uses D3's force-directed layout. It would be nice to be able to define some clustering/grouping of nodes, perhaps through positioning or drawing a shape around the group.

* **Alternate Layouts** In addition to clustering, there are many other D3 layouts that we could potentially use. (Grid, linear, hierarchical, etc)

* **Dynamically update graph** Currently, updates from the server only show when we make another request. If we could use some polling functionality, or perhaps sockets, we could dynamically show changes from the server.

* **Interactive tutorial** Since Celestrium provides a lot of plugins and features, it would be nice if we could provide an interactive tutorial for the user to get started using Celestrium to analyze datasets. There are many libraries available to do this, such as [`intro.js`](http://usablica.github.io/intro.js/).

* **Serialization and caching** On every addition to the graph, we make a request to the server. In efforts to optimize performance, we could use Javascript's `localStorage` or `sessionStorage` to make this happen.

* **Custom mapping to visual dimensions** When nodes or edges have continuous values, we want to allow the user to specify how that should be represented. Currently, we use histograms to bin link strengths. However, it could be possible that the developer can define their own views to display values and attributes of the nodes and links.

* **Graph analysis** Since we have such a well formed graph, it seems natural to be able to perform graph analysis on our data. It would be useful to have plugins for different analyses such as PageRank, shortest path, and different search algorithms.

* **Writeable Graph** Currently, our implementation is read-only. A huge feature would be to allow users to edit the graph. This would be a huge task to undertake, but would be great for users that see the need to build graphs interactively.

* **Unit Testing and Continuous Integration** We'd like to make it easy to test our separate plugins. It'd be nice to have a testing framework so that when we develop for Celestrium and contribute through pull requests, we can ensure their robustness through automatic unit tests.

* **Semantic Versioning** In addition to unit testing and continuous integration, we'd like to make Celestrium easy to develop from by declaring v1.0.0 pursuant to [semantic versioning](http://semver.org/).

## Conclusion

> TODO
