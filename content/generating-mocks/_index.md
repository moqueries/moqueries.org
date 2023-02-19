---
title: "Generating mocks"
weight: 30
---

## Bulk generation
Generating mock can be CPU intensive! Additionally, Moqueries only knows the package where to look for a type so the entire package has to be parsed. And to top it off, you will quite often mock several types from the same package. To avoid re-parsing the same package repeatedly, Moqueries has a bulk mode that can best be described by these three steps:
1. Initialize the bulk processing file
2. `go generate ./...`
3. Finalize the bulk processing (and generate all the mocks)

Moqueries [CI/CD pipeline](https://github.com/moqueries/cli/blob/main/.circleci/config.yml) accomplishes this with the following few commands:
```shell
export MOQ_BULK_STATE_FILE=$(mktemp --tmpdir= moq-XXXXXX)
moqueries bulk-initialize
go generate ./...
moqueries bulk-finalize
```

The first line creates a new temporary file to hold the state. The second line initializes the file (holds on to some global attributes to ensure consistency). The third line is the standard `go generate` line but because `MOQ_BULK_STATE_FILE` is defined, it only records the intent to generate a new mock. The forth and final line is where the work actually occurs, and it might take some time depending on how many mocks you want to generate. See more details below in the [Command line reference](#command-line-reference).

## Package generation
Adding `//go:generate` directive for every type can be quite tedious. Maybe you have a library, and you just want to provide a mock for everything. Using the `package` subcommand, you can do exactly that &mdash; generate mocks for every exported interface and function type in an entire package or module:
```shell
moqueries package github.com/myorg/mylibrary --destination-dir .
```

Use a suffix of `...` to mock all export types in all sub-packages:
```shell
moqueries package github.com/myorg/mylibrary... --destination-dir .
```

Note the package or module must should not contain any exported mocks. Moqueries mocks contain several function types and the results would include mocks of these function types. Repeated calls might actually cause an explosion of generated calls!

## More command line options
Below is a loose collection of out-of-the-ordinary command line options for use in out-of-the-ordinary situations.

### Mocking interfaces and function types in test packages
When the type you want to mock is defined in a test package, use one of the following two solutions:

1. Specify the test package (with its `_test` suffix) in the `--import` option:
    ```go
    //go:generate moqueries --import moqueries.org/cli/demo_test IsFavorite
    ```
   Note: This solution requires the `--import` option even if your Go generate directive is in the same package being imported.

   *_&mdash; OR &mdash;_*

1. Use the `--test-import` option:
    ```go
    //go:generate moqueries --test-import IsFavorite
    ```

### Exported (public) mocks
Mocks are typically generated in the test package of the destination directory. This works well in most cases including when the code you want to test lives in the same package as the code you wan to mock out. When you have lots of different packages all using the same mocks, it's better to generate the mocks once and import the mocks where needed. This is where the `--export` command line option comes into play:
```go
//go:generate moqueries --export --import io Writer
```

Now all of the mock's structs and methods are exported, so they can be used from any package:

```go
writerMoq := mockpkg.NewMoqWriter()

writerMoq.OnCall().Write([]byte("3")).ReturnResults(0, fmt.Errorf("couldn't write"))
```

## Command line reference
The Moqueries command line has the following form:

```shell
moqueries [options] [interfaces and/or function types to mock] [options]
```

Interfaces and function types are separated by whitespace. Multiple types may be specified.

| Option                             | Type     | Default value                                                                                                                        | Usage                                                                                                                                           |
|------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| `--debug`                          | `bool`   | `false`                                                                                                                              | If true, debugging output will be logged (also see `MOQ_DEBUG` in [Environment Variables](#environment-variables) below)                        |
| `--destination <file>`             | `string` | `./moq_<type>.go` when exported or `./moq_<type>_test.go` when not exported                                                          | The file path where mocks are generated relative to directory containing generate directive (or relative to the current directory)              |
| `--destination-dir <dir>`          | `string` | `.`                                                                                                                                  | The file directory where mocks are generated relative to the directory containing the generate directive (or relative to the current directory) |
| `--exclude-pkg-path-regex <regex>` | `string` | (nothing excluded)                                                                                                                   | When using the `package` subcommand, package paths matching the specified regular expression are excluded from processing                       |
| `--export`                         | `bool`   | `false`                                                                                                                              | If true, generated mocks will be exported and accessible from other packages                                                                    |
| `-h` or `--help`                   | `bool`   | `false`                                                                                                                              | Display command help                                                                                                                            |
| `--import <name>`                  | `string` | `.` (the directory containing generate directive)                                                                                    | The package containing the type (interface or function type) to be mocked                                                                       |
| `--package <name>`                 | `string` | The test package of the destination directory when `--export=false` or the package of the destination directory when `--export=true` | The package to generate code into                                                                                                               |
| `--skip-pkg-dirs <number>`         | `int`    | `0`                                                                                                                                  | When using the `package` subcommand, skips the specified number of package directories before re-creating the directory structure               |
| `--test-import`                    | `bool`   | `false`                                                                                                                              | Indicates that the types are defined in the test package                                                                                        |

Values specified after an option are separated from the option by whitespace (`--destination moq_isfavorite_test.go`) or by an equal sign (`--destination=moq_isfavorite_test.go`).

If a non-repeating option is specified more than one time, the last value is used.

Options with a value type of `bool` are set (turned on) by specifying the option directly (`--debug`) or by specifying a boolean value after the option (`--debug=true` or `--debug true`). To turn a boolean option off, a value must be specified (`--debug=false`).

### Environment Variables
The Moqueries command line can also be controlled by the following environment variables:

| Name                  | Usage                                                                                                                                                                                                       |
|-----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `MOQ_BULK_STATE_FILE` | If set, defines the bulk state file in which generate requests will be stored for bulk generation. See [Bulk generation](#bulk-generation) above.                                                           |
| `MOQ_DEBUG`           | If set to a "true" value (see [`strconv.ParseBool`](https://pkg.go.dev/strconv#ParseBool)), debugging output will be logged (also see `--debug` in [Command line reference](#command-line-reference) above) |

### Subcommands

#### Default
The default subcommand generates one or more mocks based on the command specified. As described [above](#generating-mocks), this is typically invoked by a `go:generate` directive. The default subcommand is invoked when no subcommand is specified.

If the `MOQ_BULK_STATE_FILE` environment variable is defined (see [above](#environment-variables)), the default subcommand does not immediately generate the mocks, but instead appends the generate request to the state file. See [Bulk generation](#bulk-generation) above.

#### Bulk initialize
Initializes the bulk state file defined by the `MOQ_BULK_STATE_FILE` environment variable. `MOQ_BULK_STATE_FILE` is required. Note that the bulk state file is overwritten if it exists.
```shell
moqueries bulk-initialize
```

#### Bulk finalize
Finalizes bulk processing by generating multiple mocks at once. The `MOQ_BULK_STATE_FILE` environment variable is required and specifies which mocks to generate.
```shell
moqueries bulk-finalize
```

#### Package
Generates mocks for a complete package or module as described [above](#package-generation). The package or module specified is passed as-is to [golang.org/x/tools/go/packages.Load](https://pkg.go.dev/golang.org/x/tools/go/packages) as a `pattern`.

#### Summarize metrics
The `summarize-metrics` subcommand takes the debug logs from multiple generate runs (using the [default](#default) subcommand), reads metrics from each individual run, and outputs summary metrics. This subcommand takes a single, optional argument specifying the log file to read. If no file is specified or if the file is specified as `-', standard in is read.

The following command generates all mocks specified in `go:generate` directives and summarizes the metrics for all runs:
```shell
MOQ_DEBUG=true go generate ./... | moqueries summarize-metrics
```
