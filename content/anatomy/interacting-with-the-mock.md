---
title: "Interacting with the mock"
weight: 20
---

Now that all the expectations are set, it's time to have the mock interact with some actual production code. The generated code has created a `mock` function that returns that either implements the given interface (for interface mocks) or the given function type (for function type mocks). Again some code from the main readme:
```go
d := demo.FavWriter{
    IsFav: isFavMoq.mock(),
    W:     writerMoq.mock(),
}
```

In this case, the code being tested (`FavWriter`) takes an `IsFav` function that implements a `func(n int) bool` signature and a `W` object that implements the `io.Writer` interface.

## Finding results with any parameters
Finally, a method is getting invoked on a mock! The first thing the generated code needs to navigate through is the "any" structures contained in the top-level slice [mentioned above](#any-parameters). This slice is already in the order of most specific (fewest "any" parameters) to least specific (most "any" parameters). As we iterate through the "any" structures, we have to build a parameter key specific to the given "any" structure (with zero values for parameters flagged as "any"). The bitmask in the "any" structure determines which parameters will go into the key and which parameters will stay zero values. If a map entry is found, it will contain the results needed and there is no need to continue iterating through the top-level slice.

## Nice vs. strict
So now we should have some results, right? Maybe not! If we didn't find any results and the mock is "nice", we just return some zero values. On the other hand, a "strict" mock will fail the test. Game over!

That was a fun paragraph! Must have dialed in the caffeine on this fine afternoon! If anyone would like to rewrite all of this documentation in the same tone, I would love to accept your PR!

## Which result
Now we've found the result structure [described above](#results) (assuming we didn't just return zero values). The first "write" operation we do is increment the index (again using Go's `sync/atomic` package). If the resulting value is larger than slice of result values and the expectation wasn't flagged as `AnyTimes` (and we are using a "strict" mock), the test fails. There's a lot to unwind in that last sentence so here goes: 1) if it's a "nice" mock, the mock returns zero values, 2) if the expectation is `AnyTimes`, the mock uses the last result values, or 3) if the index is within bounds of the result values slice, the mock uses the specified result values.

## Validating sequences
As each result is found, if the result defines an expected sequence number, the next sequence number is retrieved from the `Scene` (via `NextMockSequence`). If the expected sequence doesn't match the scene's next sequence, the test fails.

<a name="validating-sequences-disclaimer">**__DISCLAIMER__**:</a> You may be wondering how incrementing two atomic integers (one for the results index and another for the sequence) can be internally consistent. The answer is they aren't. Sorry! Don't use sequences in this manner. We have thought of this. There's even [a test](https://github.com/moqueries/cli/blob/main/generator/testmoqs/atomic_test.go) showing the inconsistency.

## Invoking do functions
At this stage, all the mock needs to do is invoke any "do" function defined in the results (note that "do" functions are optional so we may just return the [supplied values](#storing-results)). One obvious word of caution &mdash; if your test runs multiple Go routines, make sure your "do" functions are thread-safe and reentrant. Simple "do" functions are passed all parameters. "Do return" functions are passed all parameters and return the result values that the mock will return to the code being tested &mdash; "do return" functions actually set the return values of the mock. If both result values and a "do return" function are defined, the "do return" function takes precedence.

## Asserting all expectations are met
As a test is completing, it's common to do some additional validation. You can assert that all required expectations were called via the `AssertExpectationsMet` method. This can be called on each individual mock or for the entire `Scene` (the `Scene` simply iterates through its list of mocks and calls the method for each mock).
