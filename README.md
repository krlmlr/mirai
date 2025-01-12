
<!-- README.md is generated from README.Rmd. Please edit that file -->

# mirai <a href="https://shikokuchuo.net/mirai/" alt="mirai"><img src="man/figures/logo.png" alt="mirai logo" align="right" width="120"/></a>

<!-- badges: start -->

[![CRAN
status](https://www.r-pkg.org/badges/version/mirai?color=112d4e)](https://CRAN.R-project.org/package=mirai)
[![mirai status
badge](https://shikokuchuo.r-universe.dev/badges/mirai?color=24a60e)](https://shikokuchuo.r-universe.dev)
[![R-CMD-check](https://github.com/shikokuchuo/mirai/workflows/R-CMD-check/badge.svg)](https://github.com/shikokuchuo/mirai/actions)
[![codecov](https://codecov.io/gh/shikokuchuo/mirai/branch/main/graph/badge.svg)](https://app.codecov.io/gh/shikokuchuo/mirai)
[![DOI](https://zenodo.org/badge/459341940.svg)](https://zenodo.org/badge/latestdoi/459341940)
<!-- badges: end -->

Minimalist async evaluation framework for R. <br /><br /> Lightweight
parallel code execution and distributed computing. <br /><br /> Designed
for simplicity, a ‘mirai’ evaluates an R expression asynchronously, on
local or network resources, resolving automatically upon completion.
<br /><br /> Features efficient task scheduling, fast inter-process
communications, and Transport Layer Security over TCP/IP for remote
connections, courtesy of ‘nanonext’ and ‘NNG’ (Nanomsg Next Gen).
<br /><br /> `mirai()` returns a ‘mirai’ object immediately. ‘mirai’
(未来 みらい) is Japanese for ‘future’. <br /><br />
[`mirai`](https://doi.org/10.5281/zenodo.7912722) has a tiny pure R code
base, relying solely on
[`nanonext`](https://doi.org/10.5281/zenodo.7903429), a high-performance
binding for the ‘NNG’ (Nanomsg Next Gen) C library with zero package
dependencies. <br /><br />

### Table of Contents

1.  [Installation](#installation)
2.  [Example 1: Compute-intensive
    Operations](#example-1-compute-intensive-operations)
3.  [Example 2: I/O-bound Operations](#example-2-io-bound-operations)
4.  [Example 3: Resilient Pipelines](#example-3-resilient-pipelines)
5.  [Daemons: Local Persistent
    Processes](#daemons-local-persistent-processes)
6.  [Distributed Computing: Remote
    Daemons](#distributed-computing-remote-daemons)
7.  [Distributed Computing: TLS Secure
    Connections](#distributed-computing-tls-secure-connections)
8.  [Compute Profiles](#compute-profiles)
9.  [Errors, Interrupts and Timeouts](#errors-interrupts-and-timeouts)
10. [Integrations with Crew, Targets,
    Shiny](#integrations-with-crew-targets-shiny)
11. [Thanks](#thanks)
12. [Links](#links)

### Installation

Install the latest release from CRAN:

``` r
install.packages("mirai")
```

or the development version from rOpenSci R-universe:

``` r
install.packages("mirai", repos = "https://shikokuchuo.r-universe.dev")
```

[« Back to ToC](#table-of-contents)

### Example 1: Compute-intensive Operations

Use case: minimise execution times by performing long-running tasks
concurrently in separate processes.

Multiple long computes (model fits etc.) can be performed in parallel on
available computing cores.

Use `mirai()` to evaluate an expression asynchronously in a separate,
clean R process.

A ‘mirai’ object is returned immediately.

``` r
library(mirai)

m <- mirai(
  {
    res <- rnorm(n) + m
    res / rev(res)
  },
  m = runif(1),
  n = 1e8
)

m
#> < mirai >
#>  - $data for evaluated result
```

Above, all specified `name = value` pairs are passed through to the
‘mirai’.

The ‘mirai’ yields an ‘unresolved’ logical NA whilst the async operation
is ongoing.

``` r
m$data
#> 'unresolved' logi NA
```

Upon completion, the ‘mirai’ resolves automatically to the evaluated
result.

``` r
m$data |> str()
#>  num [1:100000000] 0.601 2.251 -0.47 0.296 0.271 ...
```

Alternatively, explicitly call and wait for the result using
`call_mirai()`.

``` r
call_mirai(m)$data |> str()
#>  num [1:100000000] 0.601 2.251 -0.47 0.296 0.271 ...
```

For easy programmatic use of `mirai()`, ‘.expr’ accepts a
pre-constructed language object, and also a list of named arguments
passed via ‘.args’. So, the following would be equivalent to the above:

``` r
expr <- quote({
  res <- rnorm(n) + m
  res / rev(res)
})

args <- list(m = runif(1), n = 1e8)

m <- mirai(.expr = expr, .args = args)

call_mirai(m)$data |> str()
#>  num [1:100000000] 6.42 3.24 0.64 2.76 1.39 ...
```

[« Back to ToC](#table-of-contents)

### Example 2: I/O-bound Operations

Use case: ensure execution flow of the main process is not blocked.

High-frequency real-time data cannot be written to file/database
synchronously without disrupting the execution flow.

Cache data in memory and use `mirai()` to perform periodic write
operations concurrently in a separate process.

Below, ‘.args’ is used to pass a list of objects already present in the
calling environment to the mirai by name. This is an alternative use of
‘.args’, and may be combined with `...` to also pass in `name = value`
pairs.

``` r
library(mirai)

x <- rnorm(1e6)
file <- tempfile()

m <- mirai(write.csv(x, file = file), .args = list(x, file))
```

A ‘mirai’ object is returned immediately.

`unresolved()` may be used in control flow statements to perform actions
which depend on resolution of the ‘mirai’, both before and after.

This means there is no need to actually wait (block) for a ‘mirai’ to
resolve, as the example below demonstrates.

``` r
# unresolved() queries for resolution itself so no need to use it again within the while loop

while (unresolved(m)) {
  cat("while unresolved\n")
  Sys.sleep(0.5)
}
#> while unresolved
#> while unresolved

cat("Write complete:", is.null(m$data))
#> Write complete: TRUE
```

Now actions which depend on the resolution may be processed, for example
the next write.

[« Back to ToC](#table-of-contents)

### Example 3: Resilient Pipelines

Use case: isolating code that can potentially fail in a separate process
to ensure continued uptime.

As part of a data science / machine learning pipeline, iterations of
model training may periodically fail for stochastic and uncontrollable
reasons (e.g. buggy memory management on graphics cards).

Running each iteration in a ‘mirai’ isolates this
potentially-problematic code such that even if it does fail, it does not
bring down the entire pipeline.

``` r
library(mirai)

run_iteration <- function(i) {
  
  if (runif(1) < 0.1) stop("random error\n", call. = FALSE) # simulates a stochastic error rate
  sprintf("iteration %d successful\n", i)
  
}

for (i in 1:10) {
  
  m <- mirai(run_iteration(i), .args = list(run_iteration, i))
  while (is_error_value(call_mirai(m)$data)) {
    cat(m$data)
    m <- mirai(run_iteration(i), .args = list(run_iteration, i))
  }
  cat(m$data)
  
}
#> iteration 1 successful
#> iteration 2 successful
#> iteration 3 successful
#> iteration 4 successful
#> iteration 5 successful
#> iteration 6 successful
#> iteration 7 successful
#> iteration 8 successful
#> iteration 9 successful
#> Error: random error
#> iteration 10 successful
```

Further, by testing the return value of each ‘mirai’ for errors,
error-handling code is then able to automate recovery and re-attempts,
as in the above example. Further details on [error
handling](#errors-interrupts-and-timeouts) can be found in the section
below.

The end result is a resilient and fault-tolerant pipeline that minimises
downtime by eliminating interruptions of long computes.

[« Back to ToC](#table-of-contents)

### Daemons: Local Persistent Processes

Daemons, or persistent background processes, may be set to receive
‘mirai’ requests.

This is potentially more efficient as new processes no longer need to be
created on an *ad hoc* basis.

#### With Dispatcher (default)

Call `daemons()` specifying the number of daemons to launch.

``` r
daemons(6)
#> [1] 6
```

To view the current status, `status()` provides the number of active
connections along with a matrix of statistics for each daemon.

``` r
status()
#> $connections
#> [1] 1
#> 
#> $daemons
#>                                     i online instance assigned complete
#> abstract://988b6c5548b89873daae7d6b 1      1        1        0        0
#> abstract://f968e887dd6aafb09af3f9ec 2      1        1        0        0
#> abstract://285a8ea0c175ea5b676ebca8 3      1        1        0        0
#> abstract://f1b2bcd7f93e7fb829970f23 4      1        1        0        0
#> abstract://6e16a65c5b1764e6a4431e4b 5      1        1        0        0
#> abstract://3843671f338e8c28f8c469ad 6      1        1        0        0
```

The default `dispatcher = TRUE` creates a `dispatcher()` background
process that connects to individual daemon processes on the local
machine. This ensures that tasks are dispatched efficiently on a
first-in first-out (FIFO) basis to daemons for processing. Tasks are
queued at the dispatcher and sent to a daemon as soon as it can accept
the task for immediate execution.

Dispatcher uses synchronisation primitives from
[`nanonext`](https://doi.org/10.5281/zenodo.7903429), waiting upon
rather than polling for tasks, which is efficient both in terms of
consuming no resources while waiting, and also being fully synchronised
with events (having no latency).

``` r
daemons(0)
#> [1] 0
```

Set the number of daemons to zero to reset. This reverts to the default
of creating a new background process for each ‘mirai’ request.

#### Without Dispatcher

Alternatively, specifying `dispatcher = FALSE`, the background daemons
connect directly to the host process.

``` r
daemons(6, dispatcher = FALSE)
#> [1] 6
```

Requesting the status now shows 6 connections, along with the host URL
at `$daemons`.

``` r
status()
#> $connections
#> [1] 6
#> 
#> $daemons
#> [1] "abstract://3a21cdc05821276862216ae1"
```

This implementation sends tasks immediately, and ensures that tasks are
evenly-distributed amongst daemons. This means that optimal scheduling
is not guaranteed as the duration of tasks cannot be known *a priori*.
As an example, tasks could be queued at a daemon behind a long-running
task, whilst other daemons remain idle.

The advantage of this approach is that it is low-level and does not
require an additional dispatcher process. It is well-suited to working
with similar-length tasks, or where the number of concurrent tasks
typically does not exceed available daemons.

``` r
daemons(0)
#> [1] 0
```

Set the number of daemons to zero to reset.

[« Back to ToC](#table-of-contents)

### Distributed Computing: Remote Daemons

The daemons interface may also be used to send tasks for computation to
remote daemon processes on the network.

Call `daemons()` specifying ‘url’ as a character string the host network
address and a port that is able to accept incoming connections.

The examples below use an illustrative local network IP address of
‘10.75.37.40’.

A port on the host machine also needs to be open and available for
inbound connections from the local network, illustratively ‘5555’ in the
examples below.

IPv6 addresses are also supported and must be enclosed in square
brackets `[]` to avoid confusion with the final colon separating the
port. For example, port 5555 on the IPv6 address `::ffff:a6f:50d` would
be specified as `tcp://[::ffff:a6f:50d]:5555`.

#### Connecting to Remote Daemons Through Dispatcher

The default `dispatcher = TRUE` creates a background `dispatcher()`
process on the local machine, which listens to a vector of URLs that
remote `daemon()` processes dial in to, with each daemon having its own
unique URL.

It is recommended to use a websocket URL starting `ws://` instead of TCP
in this scenario (used interchangeably with `tcp://`). A websocket URL
supports a path after the port number, which can be made unique for each
daemon. In this way a dispatcher can connect to an arbitrary number of
daemons over a single port.

``` r
daemons(n = 4, url = "ws://10.75.37.40:5555")
#> [1] 4
```

Above, a single URL was supplied, along with `n = 4` to specify that the
dispatcher should listen at 4 URLs. In such a case, an integer sequence
is automatically appended to the path `/1` through `/4` to produce these
URLs.

Alternatively, supplying a vector of URLs allows the use of arbitrary
port numbers / paths, e.g.:

``` r
daemons(url = c("ws://10.75.37.40:5566/cpu", "ws://10.75.37.40:5566/gpu", "ws://10.75.37.40:7788/1"))
```

Above, ‘n’ is not specified, in which case its value is inferred from
the length of the ‘url’ vector supplied.

–

On the remote resource, `daemon()` may be called from an R session, or
directly from a shell using Rscript. Each daemon instance should dial
into one of the unique URLs that the dispatcher is listening at:

    Rscript -e 'mirai::daemon("ws://10.75.37.40:5555/1")'
    Rscript -e 'mirai::daemon("ws://10.75.37.40:5555/2")'
    Rscript -e 'mirai::daemon("ws://10.75.37.40:5555/3")'
    Rscript -e 'mirai::daemon("ws://10.75.37.40:5555/4")'

Note that `daemons()` should be set up on the host machine before
launching `daemon()` on remote resources, otherwise the daemon instances
will exit if a connection is not immediately available. Alternatively,
specifying `daemon(asyncdial = TRUE)` will allow daemons to wait
(indefinitely) for a connection to become available.

`launch_remote()` may also be used to launch daemons directly on a
remote machine. For example, if the remote machine at 10.75.37.100
accepts SSH connections over port 22:

``` r
launch_remote(1:4, command = "ssh", args = c("-p 22 10.75.37.100", .))
#> [1] "Rscript -e \"mirai::daemon('ws://10.75.37.40:5555/1',rs=c(10407,234847007,-1443550508,-1219227707,585277890,326394459,-544448032))\""
#> [2] "Rscript -e \"mirai::daemon('ws://10.75.37.40:5555/2',rs=c(10407,855496323,1126561919,560666770,141328549,1513462613,-349875403))\""  
#> [3] "Rscript -e \"mirai::daemon('ws://10.75.37.40:5555/3',rs=c(10407,1901043322,1483328582,81985270,1276055119,-1503907136,-404210225))\""
#> [4] "Rscript -e \"mirai::daemon('ws://10.75.37.40:5555/4',rs=c(10407,668343214,-722105549,-1445000249,515588687,1646507310,1828364408))\""
```

The returned vector comprises the shell commands executed on the remote
machine.

–

Requesting status, on the host machine:

``` r
status()
#> $connections
#> [1] 1
#> 
#> $daemons
#>                         i online instance assigned complete
#> ws://10.75.37.40:5555/1 1      1        1        0        0
#> ws://10.75.37.40:5555/2 2      1        1        0        0
#> ws://10.75.37.40:5555/3 3      1        1        0        0
#> ws://10.75.37.40:5555/4 4      1        1        0        0
```

As per the local case, `$connections` shows the single connection to
dispatcher, however `$daemons` now provides a matrix of statistics for
the remote daemons.

- `i` index number.
- `online` shows as 1 when there is an active connection, or else 0 if a
  daemon has yet to connect or has disconnected.
- `instance` increments by 1 every time there is a new connection at a
  URL. This counter is designed to track new daemon instances connecting
  after previous ones have ended (due to time-outs etc.). The count
  becomes negative immediately after a URL is regenerated by `saisei()`,
  but increments again once a new daemon connects.
- `assigned` shows the cumulative number of tasks assigned to the
  daemon.
- `complete` shows the cumulative number of tasks completed by the
  daemon.

Dispatcher automatically adjusts to the number of daemons actually
connected. Hence it is possible to dynamically scale up or down the
number of daemons according to requirements (limited to the ‘n’ URLs
assigned).

To reset all connections and revert to default behaviour:

``` r
daemons(0)
#> [1] 0
```

Closing the connection causes the dispatcher to exit automatically, and
in turn all connected daemons when their respective connections with the
dispatcher are terminated.

#### Connecting to Remote Daemons Directly

By specifying `dispatcher = FALSE`, remote daemons connect directly to
the host process. The host listens at a single URL, and distributes
tasks to all connected daemons.

``` r
daemons(url = "tcp://10.75.37.40:0", dispatcher = FALSE)
```

Alternatively, simply supply a colon followed by the port number to
listen on all interfaces on the local host, for example:

``` r
daemons(url = "tcp://:0", dispatcher = FALSE)
#> [1] "tcp://:35989"
```

Note that above, the port number is specified as zero. This is a
wildcard value that will automatically cause a free ephemeral port to be
assigned. The actual assigned port is provided in the return value of
the call, or it may be queried at any time via `status()`.

–

On the network resource, `daemon()` may be called from an R session, or
an Rscript invocation from a shell. This sets up a remote daemon process
that connects to the host URL and receives tasks:

    Rscript -e 'mirai::daemon("tcp://10.75.37.40:35989")'

Note that `daemons()` should be set up on the host machine before
launching `daemon()` on remote resources, otherwise the daemon instances
will exit if a connection is not immediately available. Alternatively,
specifying `daemon(asyncdial = TRUE)` will allow daemons to wait
(indefinitely) for a connection to become available.

`launch_remote()` may also be used to launch daemons directly on a
remote machine. For example, if the remote machine at 10.75.37.100
accepts SSH connections over port 22:

``` r
launch_remote("tcp://10.75.37.40:35989", command = "ssh", args = c("-p 22 10.75.37.100", .))
#> [1] "Rscript -e \"mirai::daemon('tcp://10.75.37.40:35989',rs=c(10407,-1375240495,1010969182,-947866809,-26137892,-1431798227,-1249750262))\""
```

The returned vector comprises the shell commands executed on the remote
machine.

–

The number of daemons connecting to the host URL is not limited and
network resources may be added or removed at any time, with tasks
automatically distributed to all connected daemons.

`$connections` will show the actual number of connected daemons.

``` r
status()
#> $connections
#> [1] 1
#> 
#> $daemons
#> [1] "tcp://:35989"
```

To reset all connections and revert to default behaviour:

``` r
daemons(0)
#> [1] 0
```

This causes all connected daemons to exit automatically.

[« Back to ToC](#table-of-contents)

### Distributed Computing: TLS Secure Connections

TLS is available as an option to secure communications from the local
machine to remote daemons.

#### Zero-configuration

An automatic zero-configuration default is implemented. Simply specify a
secure URL of the form `wss://` or `tls+tcp://` when setting daemons.
For example, on the IPv6 loopback address:

``` r
daemons(n = 4, url = "wss://[::1]:5555")
#> [1] 4
```

Single-use keys and certificates are automatically generated and
configured, without requiring any further intervention. The private key
is always retained on the host machine and never transmitted.

The generated self-signed certificate is available via
`launch_remote()`. This function conveniently constructs the full shell
command to launch a daemon, including the correctly specified ‘tls’
argument to `daemon()`.

``` r
launch_remote(1)
#> [1] "Rscript -e \"mirai::daemon('wss://[::1]:5555/1',tls=c('-----BEGIN CERTIFICATE-----\nMIIFLTCCAxWgAwIBAgIBATANBgkqhkiG9w0BAQsFADAuMQwwCgYDVQQDDAM6OjEx\nETAPBgNVBAoMCE5hbm9uZXh0MQswCQYDVQQGEwJKUDAeFw0wMTAxMDEwMDAwMDBa\nFw0zMDEyMzEyMzU5NTlaMC4xDDAKBgNVBAMMAzo6MTERMA8GA1UECgwITmFub25l\neHQxCzAJBgNVBAYTAkpQMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA\nxx5G9OjsMAUgfKcggxLOUVWdC6sdlCQzDbzOrvEHghwphkt924pYaNgS8UKMnb46\nUFPCPfv1YtJEaUR87hLXBASnAHqvs4akXvyByI2LIREz58/q46wRbuzJq9OnbdiO\nOkcMKX423p5pRNmAbXMsJK3gPgTnr6rd54R4O8a34Dw1ZRdGKXXYYChs/CYrs4bf\niMj9RUBUGYdw24KzAybdaMTMqpysIM5D3K6sGY41n5E7ElSCfrNergpIZ9sG4okK\nekTof8EOrQSJIJ7ni+NeH3rYmcmaD9cgFtyWdPuuHWBfcWcHu6TKlM18GstKw45g\nQTUE79N2/5cnsUc9qq0ce7XaSkwdyvS1pyxaahrIft2fsttWN6v3BlHeoWs/VCRr\nEkPPMJtAJK1dql73l8m0a9siYu7ScKkY0TlKac5AFcQyfL8Tkcj9EtGTj6jxTqOP\ns5RrjehvNABdNQhCq5znmoedVuNBN9oNkQKGuKb5Tsj320oEwtgccXrIZDbmsWyZ\ne0S1EJYo4PWBM63xnlJpcwg5IOd8MFfflfjLCYU+LUnIR1ynKcAChrebNYn4+vBd\njNHjK2Ka0cFOpEl8M4YUV1acK0wjn6A8lHqXhqewihGzNJnZsI8Ltl7MP6oZL6kx\nKWHi99P6PNqCKXQNui8lPzzXuhuCP/TCmIoufN23OaUCAwEAAaNWMFQwEgYDVR0T\nAQH/BAgwBgEB/wIBADAdBgNVHQ4EFgQU2onzopjVaToXnhSPej8sfKIBRJAwHwYD\nVR0jBBgwFoAU2onzopjVaToXnhSPej8sfKIBRJAwDQYJKoZIhvcNAQELBQADggIB\nADWe5WSIMpj9dvOkb/mPx0DP+XIlHwh2FF9M1CDU20Tal2CikIFmbcXv4H27TCyg\nepB3Y++UNrptl00RwAkd/HywRXSZv053UOFqPs0BEp+kIH7lI1Ouv9adohD+f/QL\nLMFntX7Rgh4UML55hcLK2DyeMRUKlxrjtizB3eo2iZQJ71iFNO0VUbRfqboZcBol\nNIL+InGNoMbhqRecCPfg5RPsQmsp/SVAsuNa3v01A9fBsmz6O0C4C77j62gk4nUt\nPi3YU8zuoHDFuQcjHPRxt2o5svVxxxneGpmqgFg71uuLGesxa/HfOuQc9aO3kaDI\nvZKyAC0Kg/0hkEA5mNI7BGUrMSeTE4virjL+D8iiej7VpR2nntWbJhNWZamAgSZs\nFw9o2lCP17m978hk8YWSWfgG81QBkQoDEANMq5EY+fp6+G6CLs0gIRJSo289xwcT\n2TbPj8/KBJBbSZdWTd8xwtaqwg8YO/dx3OJG1k+hEcGnic9WhvE6Z5LzIm+kZPc3\nC7HjyOJYkoxqjB8SR4l3u1fmn3QX7jlcOhMj0SKXOLGFwztlehk9LPfBhuYQUtqG\n7XcBBcfqtcTS5KDXkHzuC9zTdFwerozW5hygY0KoAfTYHdjM6CmVmtVBvJ6PvuNn\nG6hl03vdqrp9FOis/D4fTxhtRqQbOBmnY1E2lNIWHrl5\n-----END CERTIFICATE-----\n',''),rs=c(10407,-885815674,-593655985,827546948,415376245,-759671374,1873324427))\""
```

The return value may be deployed manually on a remote machine by
unescaping the double quotes around the call to `"mirai::daemon()"`, or
directly via SSH or a resource manager by additionally specifying
‘command’ and ‘args’ to `launch_remote()`.

#### CA Signed Certificates

As an alternative to the zero-configuration option, a certificate may
also be generated via a Certificate Signing Request (CSR) to a
Certificate Authority (CA), which may be a public CA or a CA internal to
your organisation.

1.  Generate a private key and CSR. The following resources describe how
    to do so:

- using Mbed TLS:
  <https://mbed-tls.readthedocs.io/en/latest/kb/how-to/generate-a-certificate-request-csr/>
- using OpenSSL:
  <https://www.feistyduck.com/library/openssl-cookbook/online/> (Chapter
  1.2 Key and Certificate Management)

2.  Send or provide the generated CSR to the CA for it to sign a new TLS
    certificate.

- The received certificate should comprise a block of cipher text
  between the markers `-----BEGIN CERTIFICATE-----` and
  `-----END CERTIFICATE-----`. Make sure to request the certificate in
  the PEM format. If only available in other formats, your TLS library
  should usually provide conversion utilities.
- Check also that your private key is a block of cipher text between the
  markers `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----`.

3.  When setting daemons, the TLS certificate and private key should be
    provided to the ‘tls’ argument of `daemons()`.

- If the certificate and private key have been imported as character
  strings `cert` and `key` respectively, then the ‘tls’ argument may be
  specified as the character vector `c(cert, key)`.
- Alternatively, the certificate may be copied to a new text file, with
  the private key appended, in which case the path/filename of this new
  file may be provided to the ‘tls’ argument.

4.  When launching daemons, the certificate chain to the CA should be
    supplied to the ‘tls’ argument of `daemon()` or `launch_remote()`.

- The certificate chain should comprise multiple certificates, each
  between `-----BEGIN CERTIFICATE-----` and `-----END CERTIFICATE-----`
  markers. The first one should be the newly-generated TLS certificate,
  the same supplied to `daemons()`, and the final one should be a CA
  root certificate.
- These are the only certificates required if your certificate was
  signed directly by a CA. If not, then the intermediate certificates
  should be included in a certificate chain that starts with your TLS
  certificate and ends with the certificate of the CA.
- If these are concatenated together as a single character string
  `certchain` (and assuming no certificate revocation list), then the
  character vector `c(certchain, "")` may be supplied to the relevant
  ‘tls’ argument.
- Alternatively, if these are written to a file (and the file replicated
  on the remote machines), then the ‘tls’ argument may also be specified
  as a path/filename (assuming these are the same on each machine).

[« Back to ToC](#table-of-contents)

### Compute Profiles

The `daemons()` interface also allows the specification of compute
profiles for managing tasks with heterogeneous compute requirements:

- send tasks to different daemons or clusters of daemons with the
  appropriate specifications (in terms of CPUs / memory / GPU /
  accelerators etc.)
- split tasks between local and remote computation

Simply specify the argument `.compute` when calling `daemons()` with a
profile name (which is ‘default’ for the default profile). The daemons
settings are saved under the named profile.

To create a ‘mirai’ task using a specific compute profile, specify the
‘.compute’ argument to `mirai()`, which defaults to the ‘default’
compute profile.

Similarly, functions such as `status()`, `launch_local()` or
`launch_remote()` should be specified with the desired ‘.compute’
argument.

[« Back to ToC](#table-of-contents)

### Errors, Interrupts and Timeouts

If execution in a mirai fails, the error message is returned as a
character string of class ‘miraiError’ and ‘errorValue’ to facilitate
debugging. `is_mirai_error()` may be used to test for mirai execution
errors.

``` r
m1 <- mirai(stop("occurred with a custom message", call. = FALSE))
call_mirai(m1)$data
#> 'miraiError' chr Error: occurred with a custom message

m2 <- mirai(mirai::mirai())
call_mirai(m2)$data
#> 'miraiError' chr Error in mirai::mirai(): missing expression, perhaps wrap in {}?

is_mirai_error(m2$data)
#> [1] TRUE
is_error_value(m2$data)
#> [1] TRUE
```

If a daemon instance is sent a user interrupt, the mirai will resolve to
an empty character string of class ‘miraiInterrupt’ and ‘errorValue’.
`is_mirai_interrupt()` may be used to test for such interrupts.

``` r
is_mirai_interrupt(m2$data)
#> [1] FALSE
```

If execution of a mirai surpasses the timeout set via the ‘.timeout’
argument, the mirai will resolve to an ‘errorValue’. This can, amongst
other things, guard against mirai processes that have the potential to
hang and never return.

``` r
m3 <- mirai(nanonext::msleep(1000), .timeout = 500)
call_mirai(m3)$data
#> 'errorValue' int 5 | Timed out

is_mirai_error(m3$data)
#> [1] FALSE
is_mirai_interrupt(m3$data)
#> [1] FALSE
is_error_value(m3$data)
#> [1] TRUE
```

`is_error_value()` tests for all mirai execution errors, user interrupts
and timeouts.

[« Back to ToC](#table-of-contents)

### Integrations with Crew, Targets, Shiny

The [`crew`](https://wlandau.github.io/crew/) package is a distributed
worker-launcher that provides an R6-based interface extending `mirai` to
different distributed computing platforms, from traditional clusters to
cloud services. The
[`crew.cluster`](https://wlandau.github.io/crew.cluster/) package is a
plug-in that enables mirai-based workflows on traditional
high-performance computing clusters using LFS, PBS/TORQUE, SGE and
SLURM.

[`targets`](https://docs.ropensci.org/targets/), a Make-like pipeline
tool for statistics and data science, has integrated and adopted
[`crew`](https://wlandau.github.io/crew/) as its predominant
high-performance computing backend.

`mirai` can also serve as the backend for enterprise asynchronous
[`shiny`](https://cran.r-project.org/package=shiny) applications in one
of two ways:

1.  [`mirai.promises`](https://shikokuchuo.net/mirai.promises/), which
    enables a ‘mirai’ to be used interchangeably with a ‘promise’ in
    [`shiny`](https://cran.r-project.org/package=shiny) or
    [`plumber`](https://cran.r-project.org/package=plumber) pipelines;
    or

2.  [`crew`](https://wlandau.github.io/crew/) provides an interface that
    makes it easy to deploy `mirai` for
    [`shiny`](https://cran.r-project.org/package=shiny). The package
    provides a [Shiny
    vignette](https://wlandau.github.io/crew/articles/shiny.html) with
    tutorial and sample code for this purpose.

[« Back to ToC](#table-of-contents)

### Thanks

We would like to thank in particular:

[William Landau](https://github.com/wlandau/), for being instrumental in
shaping development of the package, from initiating the original request
for persistent daemons, through to orchestrating robustness testing for
the high performance computing requirements of
[`crew`](https://wlandau.github.io/crew/) and
[`targets`](https://docs.ropensci.org/targets/).

[Henrik Bengtsson](https://github.com/HenrikBengtsson/), for valuable
and incisive insights leading to the interface accepting broader usage
patterns.

[Luke Tierney](https://github.com/ltierney/), R Core, for pointing out
the implementation of L’Ecuyer-CMRG streams in R, for ensuring
statistical independence in parallel processing.

[« Back to ToC](#table-of-contents)

### Links

mirai website: <https://shikokuchuo.net/mirai/><br /> mirai on CRAN:
<https://cran.r-project.org/package=mirai>

Listed in CRAN Task View: <br /> - High Performance Computing:
<https://cran.r-project.org/view=HighPerformanceComputing>

nanonext website: <https://shikokuchuo.net/nanonext/><br /> nanonext on
CRAN: <https://cran.r-project.org/package=nanonext>

NNG website: <https://nng.nanomsg.org/><br />

[« Back to ToC](#table-of-contents)

–

Please note that this project is released with a [Contributor Code of
Conduct](https://shikokuchuo.net/mirai/CODE_OF_CONDUCT.html). By
participating in this project you agree to abide by its terms.
