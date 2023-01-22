---
title: "Anatomy of a Lock-free Mock"
weight: 100
---

Understanding the inner workings of a mock is not the highest priority for most developers. But since these mocks are quite a bit different internally, some extra details of the internals won't hurt.

[//]: # (TODO: link)

Before we begin zooming into the inner workings, to make the journey complete, we first need to zoom out one step &mdash; to first take a look at the whole scene. As described in the [Working with multiple mocks]({{<relref "/using-mocks/#working-with-multiple-mocks">}}):
> A `Scene` is a collection of mocks, and it allows you to perform actions on all the mocks with a single call.

So our first diagram is the big picture. We see several mocks all working together in the context of a test. The test can use the `Scene` to manipulate all of mocks at once.

![Big picture](./big-picture.svg)

Now focusing on just a few mocks and the code generated for them, we notice that they all have similar in-memory structures. Both functions and full interfaces can be mocked. When a function is mocked, there's still a mock object to maintain state. But a function mock only mocks a single function and that function is attached to the mock object by a closure created by the `mock` method (indicated here by the dashed line):

![A function moq](./fn.svg?height=300px)

A mock of an interface mocks several methods at once &mdash; all methods of the interface to meet the contract of the interface. Note that the structures for each method are independent. Again, the `mock` method returns the implementation, but for an interface mock, `mock` returns an implementation of the whole interface.

![An interface moq](./interface.svg?height=300px)

Note that both of the above diagrams simplify the interface to the rest of the system. The code that actually gets generated can be broken down into two categories:
1. __The mock interface__: This interface is an exact implementation of the interface or function type as required by the code that accepts that interface or function type.
2. __The recorder interface__: This interface is used to store expectations, and it has some similarities to the mock interface. For instance, you can use the recorder interface to tell the mock what to return when called with a specific set of parameters.

## Any parameters
As mentioned above, the structures for each method in an interface are independent from each other as are the structures for a function type mock. The first method-specific data is a slice of structures that differentiate calls with "any" parameters. "Any" parameters indicate that a specific parameter should be ignored when matching _actual_ function calls to _expected_ function calls. This top-level slice contains a structure for each combination of "any" parameters and real parameters as defined by the test. For example, if a function defines two parameters and a test expects some calls with both parameters defined and some calls with "any" first parameter, there will be two structures in this top-level slice. The slice is ordered with the most specific expectations (least "any" parameters) first.

Each of the top-level "any" structures contains a `uint64` bitmask and a count of "any" parameters. The bitmask indicates which parameters are "any" parameters. The count is used to keep the top-level slice sorted.

![Any parameters](./any-params.svg?height=300px)

## Mapping parameters to results
The next structure is a hashmap that maps a specific set of parameters to a results structure. The key of this hashmap (how things are found in the hashmap) is a structure containing a representation of each parameter. This is the parameter key `struct`. It typically is capable of holding two representations of each parameter (although only one value is actually set per parameter):
1. The parameter value itself.
2. A deep hash of the parameter.

In Go, a `struct` can be used as a map key if it is of fixed length. The value (#1 in the above list) is omitted from the generated code if the parameter value has a variable size (a slice for instance). If Moqueries didn't omit the parameter value, the map definition and the mock wouldn't compile. Therefore, variable length parameters (such as slices) can only be represented by a deep hash (`ParamIndexByHash`).

Here's a typical looking parameter key `struct` where all the parameters can be represented by their value or by their deep hash:
```go
type moqStore_LightGadgetsByWidgetId_paramsKey struct {
	params struct {
		widgetId  int
		maxWeight uint32
	}
	hashes struct {
		widgetId  hash.Hash
		maxWeight hash.Hash
	}
}
```

Here is the parameter key `struct` for the `Write` function of the mock to the `io.Writer` interface (the `byte` slice `p` can only be represented by a deep hash):
```go
type moqWriter_Write_paramsKey struct {
	params struct{}
	hashes struct{ p hash.Hash }
}
```

Which value is set (the value or the deep hash) is determined for each parameter by the `runtime` configuration. Each parameter is given a value of `ParamIndexByValue` for value matching or a value of `ParamIndexByHash` for deep hash matching. The runtime configuration shouldn't be altered after setting any expectations or the expectations may not be found.

If a parameter is an "any" parameter, the zero value (or zero value hash) is stored in the parameter key.

![Mapping parameters to results](./params-key.svg?height=300px)

## Results
The results structure stores all the result information for a given set of parameters. The first thing we see in this structure is another copy of the parameters &mdash; these parameters are complete though; there are no hashes substituted. The parameters are used when reporting errors.

![Results](./results.svg?height=300px)

Next in the results structure is a simple index. This index is an integer that is updated with Go's `sync/atomic` package. This allows multiple Go routines to update the results as each routine will increment and receive a different index value.

Finally, a slice of result values fills out the rest of the results structure. These values are actually returned to any callers. Along with the result values, the expected sequence value and any "do" functions are stored (both optional). More details on sequences follow below. "Do" functions allow a test to define side effects or store information for given calls.
