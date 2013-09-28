import os
import divisi2
import cherrypy
import sys
import simplejson as json

class ConceptProvider(object):
  
  def __init__(self, num_axes):
    A = divisi2.network.conceptnet_matrix('en')
    concept_axes, axis_weights, feature_axes = A.svd(k=num_axes)
    self.sim = divisi2.reconstruct_similarity(concept_axes, axis_weights, post_normalize=True)  
    self.concept_axes = concept_axes

  def get_nodes(self):
    return [x for x in self.concept_axes.row_labels]

  def get_edges(self, concept, otherConcepts):
    return [self.sim.entry_named(concept, c2) for c2 in otherConcepts]

  def get_related_nodes(self, selectedConcepts, allConcepts, minStrength):
    existingConceptSet = set(allConcepts)
    newNodesSet = set()
    for selectedConcept in selectedConcepts:
      limit = 100
      relatedConcepts = self.sim.row_named(selectedConcept).top_items(n=limit)
      i = 0
      while i < len(relatedConcepts) and relatedConcepts[i][1] > minStrength:
        relatedConcept, strength = relatedConcepts[i]
        if relatedConcept not in existingConceptSet:
          newNodesSet.add(relatedConcept)
        i += 1
    newNodesList = list(newNodesSet)
    crossLinks = []
    for i, existingNode in enumerate(allConcepts):
      for j, newNode in enumerate(newNodesList):
        strength = self.sim.entry_named(existingNode, newNode)
        if strength > minStrength:
          crossLinks.append({
            "source": i,
            "target": j,
            "strength": strength,
          })
    selfLinks = []
    for i in xrange(len(newNodesList) - 1):
      for j in xrange(i + 1, len(newNodesList)):
        c1, c2 = newNodesList[i], newNodesList[j]
        strength = self.sim.entry_named(c1, c2)
        if strength > minStrength:
          selfLinks.append({
            "source": i,
            "target": j,
            "strength": strength,
          })
    return newNodesList, crossLinks, selfLinks

class FacebookProvider(object):
  def __init__(self):
    self.graph = {}
    with open("data/facebook_combined.txt") as f:
      for line in f:
        a, b = line.strip().split(" ")
        self.graph.setdefault(a, set())
        self.graph.setdefault(b, set())
        self.graph[a].add(b)
        self.graph[b].add(a)
  def get_nodes(self):
    return list(self.graph.keys())
  def get_edges(self, node, otherNodes):
    return [(0.9 if x in selfgraph[node] else 0) for x in otherNodes]
  def get_related_nodes(self, selectedNodes, allNodes, minStrength):
    seen = set()
    for i, selectedNode in enumerate(selectedNodes):
      for relatedNode in self.graph[selectedNode]:
        if relatedNode not in seen and relatedNode not in selectedNodes:
          seen.add(relatedNode)
    newNodesList = list(seen)
    crossLinks = []
    for i, n1 in enumerate(selectedNodes):
      for j, n2 in enumerate(newNodesList):
        if n2 in self.graph[n1]:
          crossLinks.append({
            "source": i,
            "target": j,
            "strength": 0.9,
          })
    selfLinks = []
    for i in xrange(len(newNodesList) - 1):
      for j in xrange(i + 1, len(newNodesList)):
        n1 = newNodesList[i]
        n2 = newNodesList[j]
        if n2 in self.graph[n1]:
          selfLinks.append({
            "source": i,
            "target": j,
            "strength": 0.9,
          })
    return newNodesList, crossLinks, selfLinks

class Server(object):

  _cp_config = {'tools.staticdir.on' : True,
                'tools.staticdir.dir' : os.path.abspath(os.path.join(os.getcwd(), "web")),
                'tools.staticdir.index' : 'index.html',
                }

  def __init__(self):
    self.provider = FacebookProvider() # ConceptProvider(100)

  @cherrypy.expose
  @cherrypy.tools.json_out()
  def get_nodes(self):
    return self.provider.get_nodes();

  @cherrypy.expose
  @cherrypy.tools.json_out()
  def get_edges(self, text, allNodes):
    return self.provider.get_edges(text, json.loads(allNodes))

  @cherrypy.expose
  @cherrypy.tools.json_out()
  def get_related_nodes(self, selectedNodes, allNodes, minStrength):
    newNodesList, crossLinks, selfLinks = self.provider.get_related_nodes(
      json.loads(selectedNodes), 
      json.loads(allNodes),
      float(minStrength))
    return {
      "nodes": newNodesList,
      "crossLinks": crossLinks,
      "selfLinks": selfLinks,
    }

cherrypy.config.update({'server.socket_host': '0.0.0.0', 
                         'server.socket_port': int(sys.argv[1]), 
                        }) 

cherrypy.quickstart(Server())
