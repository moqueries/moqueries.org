---
title: "Using mocks"
weight: 20
---

## Creating a mock instance
Code generation creates a `newMoqXXX` factory function for each mock you generate. Simply [invoke the function and hold on to the new mock](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L20-L21) for further testing:
```go
isFavMoq := newMoqIsFavorite(scene, nil)
writerMoq := newMoqWriter(scene, nil)
```

You might be curious what that `scene` parameter is. A scene provides an abstraction on a collection of mocks. It allows your tests to control all of its mocks at once. There are more details on the use of scenes [below](#working-with-multiple-mocks) but for now, you can create a scene like [this](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L19):
```go
scene := moq.NewScene(t)
```

## Expectations
To get a mock to perform specific behaviors, you have to tell it what to expect and how to behave. For function mocks, the `onCall` function (generated for you) has the same parameter signature as the function itself. The return value of the `onCall` function is a type that (via its `returnResults` method) informs the mock what to return when invoked with the given set of parameters. For our `IsFavorite` function mock, we tell it to expect to be called with parameters `1`, `2` and then `3` but only `3` is our favorite number [like so](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L23-L25):
```go
isFavMoq.onCall(1).returnResults(false)
isFavMoq.onCall(2).returnResults(false)
isFavMoq.onCall(3).returnResults(true)
```

Working with interface mocks is very similar to working with function mocks. For interface mocks, the generated `onCall` method returns the expectation recorder of the mocked interface (a full implementation of the interface for recording expectations). For our `Writer` mock example, we tell it to expect a call to `Write` with the [following code](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L27-L28):
```go
writerMoq.onCall().Write([]byte("3")).
    returnResults(1, nil)
```

Note in the above code, we told the mock to return `1` and `nil` with a call to the generated `returnResults` method. Per the interface definition of a writer, we wrote one byte successfully with no errors. Alternatively, we could indicate an error with [a small change](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L51-L52):
```go
writerMoq.onCall().Write([]byte("3")).
    returnResults(0, fmt.Errorf("couldn't write"))
```

## Arbitrary (any) parameters
Sometimes it's hard to know what exactly the parameter values will be when setting expectations. You want to say "ignore this parameter" when setting some expectations. The generated `any` function does exactly that &mdash; the specified parameter will be ignored (in the recorded expectation and again later when the mock is invoked). The [following code](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L166-L167) sets the expectation for a function called `GadgetsByWidgetId` that takes a single `int` parameter called `widgetId`. With this expectation, the mock will return the same result regardless of the value of `widgetId`:
```go
storeMoq.onCall().GadgetsByWidgetId(0).any().widgetId().
    returnResults(nil, nil).repeat(moq.Times(2))
```

Expectations with more matching parameters are given precedence over expectations with fewer matching parameters. In another test, we work with another mocked method called `LightGadgetsByWidgetId` that presumably returns gadgets associated with a specified widget that are less than a specified weight. The [following snippet](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L211-L212) returns the `g1` and `g2` gadgets when `LightGadgetsByWidgetId` is called with a `widgetId` of `42` regardless of the value specified for `maxWeight`:
```go
storeMoq.onCall().LightGadgetsByWidgetId(42, 0).any().maxWeight().
    returnResults([]demo.Gadget{g1, g2}, nil)
```

In the same test, [these lines](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L225-L227) return `g3` and `g4` regardless of either parameter specified to `LightGadgetsByWidgetId`:
```go
storeMoq.onCall().LightGadgetsByWidgetId(0, 0).
	any().widgetId().any().maxWeight().
    returnResults([]demo.Gadget{g3, g4}, nil)
```

Callers will be returned `g3` and `g4` unless the `widgetId` is `42`, in which case they will be returned `g1` and `g2`.

## Parameter indexing
Each expectation is indexed by its parameters. Moqueries has two indexing mechanisms: indexing by value and indexing by hash. Indexing by value simply places the parameter value into the parameters key &mdash; a structure used to store and retrieve expectations. Indexing by hash first performs a deep hash on a given parameter value and instead stores values hash in the parameters key.

Indexing by value is preferred but there are cases that can't use indexing by value. For instance, if a slice is used as a parameter (map) key, Go would panic (or just fail to compile). Conversely, there are occasions where indexing by hash is preferred. Perhaps your test doesn't have access to the exact value used in the production code but your test code can make an identical instance &mdash; one that will have an identical hash value.

The parameter indexing for a given parameter is determined by the following rules:
1. Builtin types (except for the `error` interface) are indexed by value.
2. Arrays (with a specified length) containing builtin types are indexed by value.
3. Structures (including structures within structures) containing builtin types are indexed by value.
4. Any composition of rules #1 through #3 (structures containing arrays or arrays containing structures all containing builtin types) are indexed by value.
5. Slices, maps and ellipses (`...`) parameters are indexed by hash.
6. References and interfaces are indexed by hash.

All the above rules can be overridden except for #5 &mdash; as mentioned above, indexing by value here would cause a panic.  To change the indexing mechanism for a given parameter, use the `runtime.parameterIndexing` configuration:
```go
storeMoq.runtime.parameterIndexing.LightGadgetsByWidgetId.widgetId = moq.ParamIndexByHash
```

## Repeated results
When expectations need to be returned repeatedly, the `repeat` function can be called with a list of repeaters. Some examples of repeaters are `Times` and `AnyTimes` can be used to control how often a particular result is returned. For instance, [the following code](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L77-L79) instructs the mock function to return `false` five times and then `true` one time (one time is the default):
```go
isFavMoq.onCall(7).
    returnResults(false).repeat(moq.Times(5)).
    returnResults(true)
```

`AnyTimes` instructs the mock to repeatedly return the same values regardless of how many times the function is called with the given parameters. Note that `AnyTimes` can only be used once for a given set of parameters.

`Times` and `AnyTimes` can be used together as well. [This code](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L136-L138) returns `true` twice and then always returns `false` regardless of how many times the function is called with the parameter `7`:
```go
isFavMoq.onCall(7).
    returnResults(true).repeat(moq.Times(2)).
    returnResults(false).repeat(moq.AnyTimes())
```

Using `MinTimes` and/or `MaxTimes`, you can assert a [minimum number](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L404-L406), [maximum number](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L401-L403) or [range (min and max)](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L407-L409) of calls were made:
```go
isFavMoq.onCall(1).
    returnResults(false).
    repeat(moq.MaxTimes(3))
isFavMoq.onCall(2).
    returnResults(false).
    repeat(moq.MinTimes(2))
isFavMoq.onCall(3).
    returnResults(true).
    repeat(moq.MinTimes(1), moq.MaxTimes(3))
```

`Optional` can be used to indicate that none of the calls are required (the equivalent of `MinTimes(0)`). `Optional` can be [called by itself](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L432-L434) (with `MaxTimes(1)` assumed), or [with an explicit call to `MaxTimes`](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L435-L437) or [with an explicit call to `Times`](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L443-L445):
```go
isFavMoq.onCall(0).
    returnResults(false).
    repeat(moq.Optional())
isFavMoq.onCall(1).
    returnResults(false).
    repeat(moq.Optional(), moq.MaxTimes(3))
isFavMoq.onCall(2).
    returnResults(false).
    repeat(moq.MinTimes(2))
isFavMoq.onCall(4).
    returnResults(false).
    repeat(moq.Optional(), moq.Times(3))
```

Note that some repeated result combinations are not supported and will cause a test failure during setup. For instance,
specifying that a call should be made `MinTimes(3)` and `Optional` is not allowed.

## Asserting call sequences
Some test writers want to make sure not only were certain calls made but also that the calls were made in an exact order. If you want to assert that all calls for a test are to be in order, just set the mock's [default to use sequences](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L101) on all calls via the `Config` value:
```go
config := moq.Config{Sequence: moq.SeqDefaultOn}
```

Now the calls to all mocks using the above config must be in the exact sequence. The sequence of expectations must match the sequence of calls to the mock.

If there are just a few calls that must be in a specific order relative to each other, [call the `seq` method](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L268-L270) when recording expectations:
```go
isFavMoq.onCall(1).seq().returnResults(false)
isFavMoq.onCall(2).seq().returnResults(false)
isFavMoq.onCall(3).seq().returnResults(true)
```

This is basically overriding the default so that just the calls specified use a sequence. You can also turn off sequences on a per-call basis when the default is to use sequences on all calls [using the `noSeq` method](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L298-L299):
```go
writerMoq.onCall().Write([]byte("3")).noSeq().
    returnResults(1, nil)
```

## Do functions
Sometimes you need to tap into what your mock is doing. You may need to capture a value that was passed to a mock, or you may need to have some logic calculate what a mock's response should be. Do functions do just that. If you just need to listen in to a `returnResults` expectation, you provide a [function that matches the mocked functions parameters](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L319-L322) (in this case the mocked function takes a single `int` parameter):
```go
sum := 0
sumFn := func(n int) {
    sum += n
}
```

Then [chain](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L324-L326) an `andDo` call after the `returnResults` call:
```go
isFavMoq.onCall(1).returnResults(false).andDo(sumFn)
isFavMoq.onCall(2).returnResults(false).andDo(sumFn)
isFavMoq.onCall(3).returnResults(true).andDo(sumFn)
```

If on the other hand you need to calculate a mock's return values, start with [a function that has the same signature as the mocked function](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L353-L355) (both parameters and result values):
```go
isFavFn := func(n int) bool {
    return n%2 == 0
}
```

Now you can replace both the `returnResults` and `andDo` calls with [a single call](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L357-L358) to `doReturnResults`:
```go
isFavMoq.onCall(0).any().n().
    doReturnResults(isFavFn).repeat(moq.AnyTimes())
```

Note this expectation will return the calculated value (`n%2 == 0`) regardless of the input parameters and regardless of how may times it is invoked.

## Passing the mock to production code
Each mock gets a generated `mock` method. This function accesses the implementation of the interface or function invoked by production code. In [our example](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L30-L33), we have a type called `FavWriter` that needs an `IsFavorite` function and a `Writer`:
```go
d := demo.FavWriter{
    IsFav: isFavMoq.mock(),
    W:     writerMoq.mock(),
}
```

## Nice vs. Strict
Sometimes your mocks will get lots of function calls with lots of different parameters &mdash; maybe more calls than you can (or want) to configure. Nice mocks trigger special logic that allow them to return zero values for any unexpected calls. [Creating a nice mock](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L45-L46) is as simple as supplying a little configuration to the `new` method (the value was `nil` above which defaults to creating strict mocks):
```go
isFavMoq := newMoqIsFavorite(
    scene, &moq.Config{Expectation: moq.Nice})
```

Now we only need to [set expectations](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L49) when returning non-zero values (`returnResults(false)` is now the default):
```go
isFavMoq.onCall(3).returnResults(true)
```

Calling this mock with any value besides `3` will now return `false` (without having to register any other expectations).

## Asserting all expectations are met
After your test runs, you may want to verify that all of your expectations were actually met. Each mock implements `AssertExpectationsMet` to [do just that](https://github.com/moqueries/cli/blob/main/demo/demo_test.go#L40):
```go
writerMoq.AssertExpectationsMet()
```

## Resetting the state
Occasionally you need reset the state of a mock. Re-creating the mock is preferred but there are situations where that isn't possible (maybe a long-running test, or the mock has already been handed off to other code). In any case, calling `Reset` does just that &mdash; it resets the mock:
```go
writerMoq.Reset()
```

## Working with multiple mocks
Quite often tests will require several mocks. A `Scene` is a collection of mocks, and it allows you to perform actions on all the mocks with a single call. Both `AssertExpectationsMet` and `Reset` are supported:
```go
scene.AssertExpectationsMet()
```
