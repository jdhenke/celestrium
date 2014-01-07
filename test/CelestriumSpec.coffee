class Alpha
  @uri: "alpha"
  constructor: (@arg) ->

class Bravo
  @uri: "bravo"
  @needs:
    "alpha": "alpha"

class Charlie
  @uri: "charlie"
  @extends: "DataProvider"

describe "celestrium", () ->
  it "should be defined", () ->
    expect(celestrium).toBeDefined()

describe "registering plugins", () ->
  it "should be defined", () ->
    expect(celestrium.register).toBeDefined()

celestrium.register(Alpha)
celestrium.register(Bravo)
celestrium.register(Charlie)

describe "describe initializing plugins", () ->

  it "should be defined", () ->
    expect(celestrium.init).toBeDefined()

  testArgValue = "testArg"
  it "construct plugins with arguments", () ->
    celestrium.init
      "alpha": testArgValue
    , (instances) ->
      expect(instances).toBeDefined()
      expect(instances[Alpha.uri]).toBeDefined()
      expect(instances[Alpha.uri].arg).toBe(testArgValue)

  it "uses class's @needs", () ->
    celestrium.init
      "alpha": testArgValue
      "bravo": {}
    , (instances) ->
      expect(instances[Bravo.uri].alpha).toBeDefined()
      expect(instances[Bravo.uri].alpha.arg).toBe(testArgValue)
    it "and doesn't modify the underlying class definition", () ->

  it "uses class's @extends", () ->
    celestrium.init
      "charlie": {}
    , (instances) ->
      expect(instances[Charlie.uri].nodeFilter).toBeDefined()
