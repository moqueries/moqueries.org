---
title: "Storing expectations"
weight: 10
---

Now that we see the basic structure, the next step is to store some expectations so that our mocks can start interacting with the code being tested. Note that a mock is thread-safe and reentrant via its mock interface only and only after expectations are set. Expectations should only be set via single-threaded test setup code.

Each mock has a generated DSL for assembling expectations. Details gathered via the DSL include:
1. Parameters
2. Which parameters are "any" parameters
3. Whether a sequence should be checked
4. How many times the function might be called (min, max, etc.)
5. What the result values for each call will be

Here is one of the more complex expectations from the main readme:
```go
storeMoq.onCall().LightGadgetsByWidgetId(0, 10).any().widgetId().
	returnResults([]demo.Gadget{g3, g4}, nil).repeat(moq.Times(5)).
	returnResults(nil, errors.New("too much")).repeat(moq.AnyTimes())
```

Translated into English, the expectation from running the test is that `LightGadgetsByWidgetId` will be called with any `widgetId` (the first parameter; note the zero value is ignored) and a `maxWeight` of `10` (the second parameter). The result values for the first five calls will be `[]demo.Gadget{g3, g4}` and `nil`. Any number of calls can be made and all calls after the first five calls will return `nil` and a "too much" error. We will use this example repeatedly throughout the rest of the guide.

Note that remainder of this "Storing expectations" section describes what the generated code does for you. All you have to do is set expectations in a test similar to the Go code above.

## Storing any parameters
The first step in storing expectations is to calculate the "any" parameters bitmask and count how many bits are set (or how many parameters are "any"). In the above example expectation, the first parameter is an "any" and the second is not resulting in a `0b01` bitmask and a bit count of `1`. Then the top-level slice (described [above](#any-parameters)) is scanned for any entry with the same bitmask. If one isn't found, a new entry is created positioned so that the entries are in order of increasing bit counts.

![Storing any parameters](../store-any-params.svg?height=300px)

## Building a parameter key
Next up in the process of storing expectation is to create an entry in the parameter-to-results map [mentioned above](#mapping-parameters-to-results). And as mentioned above, the key to this map is a structure containing a copy or a deep hash of each parameter (or the zero value if representing an "any" parameter). Going back to the example expectation, the map key structure looks like the following (here the `widgetId` has a zero value and `maxWeight` is represented as a hash):
```go
paramsKey := moqStore_LightGadgetsByWidgetId_paramsKey{
    params: struct {
        widgetId  int
        maxWeight uint32
    }{
        widgetId: 0,
    },
    hashes: struct {
        widgetId  hash.Hash
        maxWeight hash.Hash
    }{
        maxWeight: 0xf7431a2832fec7a8,
    },
}
```

Note that the first parameter will always be represented by a zero value because it is an "any" parameter (even if a real value was supplied, it is ignored). The second value is not specified in the `params` section but does have a hash in the `hashes` section. Deep hashes are represented by the `moqueries.org/runtime/hash.Hash` type (which is just a `uint64`).

## Storing results
The last step in storing expectations is building the results structure. As [mentioned above](#results), this includes the parameters, repeat information, a results index (initialized to `0`), and a slice of result values. Over the course of setting multiple expectations, the same parameters used for the same mock function call can "grow" the results structure. When all expectations are set, the slice of result values will contain an entry for each expected invocation (up to the defined max) plus one set of result values if repeating with the `AnyTimes` function.
```go
type moqStore_LightGadgetsByWidgetId_results struct {
	params  moqStore_LightGadgetsByWidgetId_params
	results []struct {
		values *struct {
			result1 []demo.Gadget
			result2 error
		}
		...
	}
	index  uint32
	repeat *moq.RepeatVal
}

resultsByParams[paramsKey] = &moqStore_LightGadgetsByWidgetId_results{
	params:  moqStore_LightGadgetsByWidgetId_params{
		widgetId:  0,
		maxWeight: 10,
	},
	results: nil,
	index:   0,
	repeat:  &moq.RepeatVal{
		MinTimes:    5,
		MaxTimes:    5,
		AnyTimes:    true,
		...
	},
}
```

The inner `results` slice contains a copy of the result values for each invocation plus a set of result values for any additional calls (the `AnyTimes` result values):
```go
results := {
	{
		values: {
			result1: []demo.Gadget{g3, g4},
			result2: nil,
        },
		...
    },
	{
		values: {
			result1: []demo.Gadget{g3, g4},
			result2: nil,
		},
		...
	},
	...
	// Here are the `AnyTimes` results that will be returned repeatedly
	{
		values: {
			result1: nil,
			result2: errors.New("too much"),
		},
		...
	},
}
```

![Storing any parameters](../store-params-key.svg?height=300px)

## Expecting call sequences
Each expectation can require that it be called in a specific order or sequence of calls. Each mock has is a default sequence configuration which indicates that all expectations will be sequenced or no expectations will be sequenced. Each individual expectation can override the default by calling either `seq` (when the default is no sequences) or `noSeq` (when the default is all sequences). As each expectation is set (potentially repeatedly set when `repeat` is used), the next expected sequence value is retrieved from the scene and stored with the result values (not shown in the above code samples).

## Do functions
"Do" functions allow side effects to be defined for each expectation. There are two types of "do" function defined for each method: 1) simple "do" functions take all parameters (intended to just pass the parameters back to the test) and 2) "do return" functions that take all parameters and return results that will be passed back to the code being tested. Multiple expectations can set either type of "do" function to the same function or different functions can be defined for each result.
