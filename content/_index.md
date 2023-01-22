---
title: "Home"
weight: 0
---

## Moqueries - Lock-free interface and function mocks for Go
Moqueries makes mocks, but not just interface mocks &mdash; `moqueries` builds mocks for functions too. And these aren't your typical mocks!

Moqueries mocks are, as mentioned above, lock free. Why would that matter? A single lock per mock shouldn't slow down your unit tests that much, right? The problem isn't speed but semantics. Having all interactions in your tests synchronized by locking just to protect mock state changes the nature of the test. That lock in your old mock could be hiding subtle bugs from Go's race detector!

These mocks are also true to the interface and function types they mock &mdash; several mock generators record your intentions with method signatures like `DoIt(arg0, arg1, arg2 interface{})` (or worse `DoIt(args ...interface{})`) when your interface is something like `DoIt(lFac, rFac *xyz.Factor, msg string)`. This applies to both parameters passed into the recorder and result values. Having a true implementation means that your IDE and the compiler both know what the types should be which improves your cycle time.

Next steps:
* Explore the [quick-start guide]({{<relref "quick-start.md">}})
* If you would like to learn more about the internals of a lock-free mock, take a look at the [Anatomy of a Lock-free Mock]({{<relref "anatomy">}}).

## Getting Support
Feel free to start a conversation in the [Moqueries channel on Gophers Slack](https://gophers.slack.com/archives/C04H7N80FT5). To report an issue or browse existing issues, the [CLI issues](https://github.com/moqueries/cli/issues) is a good place to start.

## License
Moqueries is licensed under the [BSD 3-Clause License](https://github.com/moqueries/cli/blob/main/LICENSE).
