# Copyright (C) 2022-2023 Hibiki AI Limited <info@hibiki-ai.com>
#
# This file is part of mirai.
#
# mirai is free software: you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation, either version 3 of the License, or (at your option) any later
# version.
#
# mirai is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# mirai. If not, see <https://www.gnu.org/licenses/>.

# mirai ------------------------------------------------------------------------

#' Daemons (Configure Persistent Processes)
#'
#' Set 'daemons' or persistent background processes receiving \code{\link{mirai}}
#'     requests. These are by default created on the local machine.
#'     Alternatively, for distributing tasks across the network, a host URL
#'     may be specified to receive connections from remote daemons started with
#'     \code{\link{daemon}}. Daemons may use either the dispatcher, which
#'     ensures tasks are assigned to daemons efficiently on a FIFO basis, or
#'     else the low-level approach of distributing tasks to daemons equally.
#'
#' @inheritParams dispatcher
#' @param n integer number of daemons to set.
#' @param url [default NULL] if specified, the character URL or vector of URLs
#'     on the host for remote daemons to dial into, including a port accepting
#'     incoming connections (and optionally for websockets, a path), e.g.
#'     'tcp://192.168.0.2:5555' or 'ws://192.168.0.2:5555/path'. Specify a URL
#'     starting 'tls+tcp://' or 'wss://' to use secure TLS connections.
#' @param dispatcher [default TRUE] logical value whether to use dispatcher.
#'     Dispatcher is a local background process that connects to daemons on
#'     behalf of the host and ensures FIFO scheduling, queueing tasks if
#'     necessary (see Dispatcher section below).
#' @param resilience [default TRUE] (applicable for when not using dispatcher)
#'     logical value whether to retry failed tasks on other daemons. If FALSE,
#'     an appropriate 'errorValue' will be returned in such cases.
#' @param seed [default NULL] (optional) supply a random seed (single value,
#'     interpreted as an integer). This is used to inititalise the L'Ecuyer-CMRG
#'     RNG streams sent to each daemon. Note that reproducible results can be
#'     expected only for 'dispatcher = FALSE', as the unpredictable timing of
#'     task completions would otherwise influence the tasks sent to each daemon.
#'     Even for 'dispatcher = FALSE', reproducibility is not guaranteed if the
#'     order in which tasks are sent is not deterministic.
#' @param tls [default NULL] (optional for secure TLS connections) if not
#'     supplied, zero-configuration single-use keys and certificates are
#'     automatically generated. If supplied, \strong{either} the character path
#'     to a file containing the PEM-encoded TLS certificate and associated
#'     private key (may contain additional certificates leading to a validation
#'     chain, with the TLS certificate first), \strong{or} a length 2 character
#'     vector comprising [i] the TLS certificate (optionally certificate chain)
#'     and [ii] the associated private key.
#' @param ... additional arguments passed through to \code{\link{dispatcher}} if
#'     using dispatcher and/or \code{\link{daemon}} if launching local daemons.
#' @param .compute [default 'default'] character compute profile to use for
#'     creating the daemons (each compute profile has its own set of daemons for
#'     connecting to different resources).
#'
#' @return Depending on the arguments supplied:
#'
#'     \itemize{
#'     \item{using dispatcher: integer number of daemons set.}
#'     \item{or else launching local daemons: integer number of daemons launched.}
#'     \item{otherwise: the character host URL.}
#'     }
#'
#' @details Use \code{daemons(0)} to reset daemon connections:
#'     \itemize{
#'     \item{A reset is required before revising settings for the same compute
#'     profile, otherwise changes are not registered.}
#'     \item{All connected daemons and/or dispatchers exit automatically.}
#'     \item{\pkg{mirai} reverts to the default behaviour of creating a new
#'     background process for each request.}
#'     \item{Any unresolved 'mirai' will return an 'errorValue' 7 (Object
#'     closed) after a reset.}
#'     }
#'
#'     If the host session ends, for whatever reason, all connected dispatcher
#'     and daemon processes automatically exit as soon as their connections are
#'     dropped. If a daemon is processing a task, it will exit as soon as the
#'     task is complete.
#'
#'     For historical reasons, \code{daemons()} with no arguments returns the
#'     value of \code{\link{status}}.
#'
#' @section Dispatcher:
#'
#'     By default \code{dispatcher = TRUE}. This launches a background process
#'     running \code{\link{dispatcher}}. Dispatcher connects to daemons on
#'     behalf of the host and queues tasks until a daemon is able to begin
#'     immediate execution of that task, ensuring FIFO scheduling. Dispatcher
#'     uses synchronisation primitives from \code{nanonext}, waiting rather than
#'     polling for tasks, which is efficient both in terms of consuming no
#'     resources while waiting, and also being fully synchronised with events
#'     (having no latency).
#'
#'     By specifying \code{dispatcher = FALSE}, daemons connect to the host
#'     directly rather than through dispatcher. The host sends tasks to
#'     connected daemons immediately in an evenly-distributed fashion. However,
#'     optimal scheduling is not guaranteed as the duration of tasks cannot be
#'     known \emph{a priori}, such that tasks can be queued at a daemon behind
#'     a long-running task while other daemons remain idle. Nevertheless, this
#'     provides a resource-light approach suited to working with similar-length
#'     tasks, or where concurrent tasks typically do not exceed available daemons.
#'
#' @section Local Daemons:
#'
#'     Daemons provide a potentially more efficient solution for asynchronous
#'     operations as new processes no longer need to be created on an \emph{ad
#'     hoc} basis.
#'
#'     Supply the argument 'n' to set the number of daemons. New background
#'     \code{\link{daemon}} processes are automatically created on the local
#'     machine connecting back to the host process, either directly or via a
#'     dispatcher.
#'
#' @section Distributed Computing:
#'
#'     Specifying 'url' allows tasks to be distributed across the network.
#'
#'     The host URL should be a character string such as: 'tcp://192.168.0.2:5555'
#'     at which daemon processes started using \code{\link{daemon}} should
#'     connect to. The full shell command to deploy on remote machines may be
#'     generated by \code{\link{launch_remote}}.
#'
#'     IPv6 addresses are also supported and must be enclosed in square brackets
#'     [ ] to avoid confusion with the final colon separating the port. For
#'     example, port 5555 on the IPv6 loopback address ::1 would be specified
#'     as 'tcp://[::1]:5555'.
#'
#'     Alternatively, to listen to port 5555 on all interfaces on the local host,
#'     specify either 'tcp://:5555', 'tcp://*:5555' or 'tcp://0.0.0.0:5555'.
#'
#'     Specifying the wildcard value zero for the port number e.g. 'tcp://:0' or
#'     'ws://:0' will automatically assign a free ephemeral port. Use
#'     \code{\link{status}} to inspect the actual assigned port at any time.
#'
#'     \strong{With Dispatcher}
#'
#'     When using dispatcher, it is recommended to use a websocket URL rather
#'     than TCP, as this requires only one port to connect to all daemons: a
#'     websocket URL supports a path after the port number, which can be made
#'     unique for each daemon.
#'
#'     Specifying a single host URL such as 'ws://192.168.0.2:5555' with
#'     \code{n = 6} will automatically append a sequence to the path, listening
#'     to the URLs 'ws://192.168.0.2:5555/1' through 'ws://192.168.0.2:5555/6'.
#'
#'     Alternatively, specify a vector of URLs to listen to arbitrary port
#'     numbers / paths. In this case it is optional to supply 'n' as this can
#'     be inferred by the length of vector supplied.
#'
#'     Individual \code{\link{daemon}} instances should then be started on the
#'     remote resource, which dial in to each of these host URLs. At most one
#'     daemon should be dialled into each URL at any given time.
#'
#'     Dispatcher automatically adjusts to the number of daemons actually
#'     connected. Hence it is possible to dynamically scale up or down the
#'     number of daemons as required, subject to the maximum number initially
#'     specified.
#'
#'     Alternatively, supplying a single TCP URL will listen at a block of URLs
#'     with ports starting from the supplied port number and incrementing by one
#'     for 'n' specified e.g. the host URL 'tcp://192.168.0.2:5555' with
#'     \code{n = 6} listens to the contiguous block of ports 5555 through 5560.
#'
#'     \strong{Without Dispatcher}
#'
#'     A TCP URL may be used in this case as the host listens at only one
#'     address, utilising a single port.
#'
#'     The network topology is such that daemons (started with \code{\link{daemon}})
#'     or indeed dispatchers (started with \code{\link{dispatcher}}) dial into
#'     the same host URL.
#'
#'     'n' is not required in this case, and disregarded if supplied, as network
#'     resources may be added or removed at any time. The host automatically
#'     distributes tasks to all connected daemons and dispatchers.
#'
#' @section Compute Profiles:
#'
#'     By default, the 'default' compute profile is used. Providing a character
#'     value for '.compute' creates a new compute profile with the name
#'     specified. Each compute profile retains its own daemons settings, and may
#'     be operated independently of each other. Some usage examples follow:
#'
#'     \strong{local / remote} daemons may be set with a host URL and specifying
#'     '.compute' as 'remote', which creates a new compute profile. Subsequent
#'     mirai calls may then be sent for local computation by not specifying its
#'     '.compute' argument, or for remote computation to connected daemons by
#'     specifying its '.compute' argument as 'remote'.
#'
#'     \strong{cpu / gpu} some tasks may require access to different types of
#'     daemon, such as those with GPUs. In this case, \code{daemons()} may be
#'     called twice to set up host URLs for CPU-only daemons and for those
#'     with GPUs, specifying the '.compute' argument as 'cpu' and 'gpu'
#'     respectively. By supplying the '.compute' argument to subsequent mirai
#'     calls, tasks may be sent to either 'cpu' or 'gpu' daemons as appropriate.
#'
#'     Note: further actions such as resetting daemons via \code{daemons(0)}
#'     should be carried out with the desired '.compute' argument specified.
#'
#' @section Timeouts:
#'
#'     Specifying the \code{.timeout} argument in \code{\link{mirai}} will ensure
#'     that the 'mirai' always resolves.
#'
#'     However, the task may not have completed and still be ongoing in the
#'     daemon process. In such situations, dispatcher ensures that queued tasks
#'     are not assigned to the busy process, however overall performance may
#'     still be degraded if they remain in use. If a process hangs and cannot be
#'     restarted manually, \code{\link{saisei}} specifying \code{force = TRUE}
#'     may be used to cancel the task and regenerate any particular URL for a
#'     new \code{\link{daemon}} to connect to.
#'
#' @examples
#' if (interactive()) {
#' # Only run examples in interactive R sessions
#'
#' # Create 2 local daemons (using dispatcher)
#' daemons(2)
#' status()
#' # Reset to zero
#' daemons(0)
#'
#' # Create 2 local daemons (not using dispatcher)
#' daemons(2, dispatcher = FALSE)
#' status()
#' # Reset to zero
#' daemons(0)
#'
#' # 2 remote daemons via dispatcher (using zero wildcard)
#' daemons(2, url = "ws://:0")
#' status()
#' # Reset to zero
#' daemons(0)
#'
#' # Set host URL for remote daemons to dial into (using zero wildcard)
#' daemons(url = "tcp://:0", dispatcher = FALSE)
#' status()
#' # Reset to zero
#' daemons(0)
#'
#' }
#'
#' @export
#'
daemons <- function(n, url = NULL, dispatcher = TRUE, resilience = TRUE,
                    seed = NULL, tls = NULL, pass = NULL, ..., .compute = "default") {

  missing(n) && missing(url) && return(status(.compute))

  envir <- ..[[.compute]]
  if (is.null(envir))
    envir <- `[[<-`(.., .compute, new.env(hash = FALSE, parent = ..))[[.compute]]

  if (is.character(url)) {

    if (is.null(envir[["sock"]])) {
      purl <- parse_url(url)
      if (substr(purl[["scheme"]], 1L, 3L) %in% c("wss", "tls") && is.null(tls)) {
        tls <- write_cert(cn = purl[["hostname"]])
        envir[["tls"]] <- tls[["client"]]
        tls <- tls[["server"]]
      }
      create_stream(n = n, seed = seed, envir = envir)
      if (dispatcher) {
        n <- if (missing(n)) length(url) else if (is.numeric(n) && n >= 1L) as.integer(n) else stop(.messages[["n_one"]])
        if (length(tls)) tls_config(server = tls, pass = pass)
        urld <- auto_tokenized_url()
        urlc <- strcat(urld, "c")
        sock <- req_socket(urld, resend = 0L)
        sockc <- req_socket(urlc, resend = 0L)
        launch_and_sync_daemon(sock = sock, urld, parse_dots(...), url, n, urlc, tls = tls, pass = pass)
        init_monitor(sockc = sockc, envir = envir)
      } else {
        sock <- req_socket(url, tls = if (length(tls)) tls_config(server = tls, pass = pass), resend = resilience * .intmax)
        listener <- attr(sock, "listener")[[1L]]
        n <- opt(listener, "url")
        if (parse_url(n)[["port"]] == "0")
          n <- sub_real_port(port = opt(listener, "tcp-bound-port"), url = n)
        `[[<-`(envir, "urls", n)
      }
      `[[<-`(`[[<-`(`[[<-`(envir, "sock", sock), "n", n), "cv", cv())
    }

  } else {

    is.numeric(n) || stop(.messages[["numeric_n"]])
    n <- as.integer(n)

    if (n == 0L) {
      length(envir[["n"]]) || return(0L)

      reap(envir[["sock"]])
      length(envir[["sockc"]]) && reap(envir[["sockc"]])
      envir <- NULL
      `[[<-`(.., .compute, new.env(hash = FALSE, parent = ..))

    } else if (is.null(envir[["sock"]])) {

      n > 0L || stop(.messages[["n_zero"]])
      urld <- auto_tokenized_url()
      create_stream(n = n, seed = seed, envir = envir)
      if (dispatcher) {
        sock <- req_socket(urld, resend = 0L)
        urlc <- strcat(urld, "c")
        sockc <- req_socket(urlc, resend = 0L)
        launch_and_sync_daemon(sock = sock, urld, parse_dots(...), n, urlc, rs = envir[["stream"]])
        for (i in seq_len(n)) next_stream(envir)
        init_monitor(sockc = sockc, envir = envir)
      } else {
        sock <- req_socket(urld, resend = resilience * .intmax)
        if (is.null(seed) || n == 1L) {
          for (i in seq_len(n))
            launch_daemon(urld, parse_dots(...), next_stream(envir))
        } else {
          for (i in seq_len(n))
            launch_and_sync_daemon(sock = sock, urld, parse_dots(...), next_stream(envir))
        }
        `[[<-`(envir, "urls", urld)
      }
      `[[<-`(`[[<-`(`[[<-`(envir, "sock", sock), "n", n), "cv", cv())
    }

  }

  if (length(envir[["n"]])) envir[["n"]] else 0L

}

#' Status Information
#'
#' Retrieve status information for the specified compute profile, comprising
#'     current connections and daemons status.
#'
#' @param .compute [default 'default'] character compute profile (each compute
#'     profile has its own set of daemons for connecting to different resources).
#'     Alternatively specify a 'miraiCluster' to obtain its status.
#'
#' @return A named list comprising:
#'     \itemize{
#'     \item{\strong{connections}} {- integer number of active connections.
#'     \cr Using dispatcher: Always 1L as there is a single connection to
#'     dispatcher, which connects to the daemons in turn.}
#'     \item{\strong{daemons}} {- of variable type.
#'     \cr Using dispatcher: a status matrix (see Status Matrix section below),
#'     or else an integer 'errorValue' if communication with dispatcher failed.
#'     \cr Not using dispatcher: the character host URL.
#'     \cr Not set: 0L.}
#'     }
#'
#' @section Status Matrix:
#'
#'     When using dispatcher, \code{$daemons} comprises an integer matrix with
#'     the following columns:
#'     \itemize{
#'     \item{\strong{i}} {- integer index number.}
#'     \item{\strong{online}} {- shows as 1 when there is an active connection,
#'     or else 0 if a daemon has yet to connect or has disconnected.}
#'     \item{\strong{instance}} {- increments by 1 every time there is a new
#'     connection at a URL. This counter is designed to track new daemon
#'     instances connecting after previous ones have ended (due to time-outs
#'     etc.). The count becomes negative immediately after a URL is regenerated
#'     by \code{\link{saisei}}, but increments again once a new daemon connects.}
#'     \item{\strong{assigned}} {- shows the cumulative number of tasks assigned
#'     to the daemon.}
#'     \item{\strong{complete}} {- shows the cumulative number of tasks
#'     completed by the daemon.}
#'     }
#'     The dispatcher URLs are stored as row names to the matrix.
#'
#' @examples
#' if (interactive()) {
#' # Only run examples in interactive R sessions
#'
#' status()
#' daemons(n = 2L, url = "wss://[::1]:0")
#' status()
#' daemons(0)
#'
#' }
#'
#' @export
#'
status <- function(.compute = "default") {

  is.list(.compute) && return(status(attr(.compute, "id")))
  envir <- ..[[.compute]]
  sock <- envir[["sock"]]
  list(connections = if (is.null(sock)) 0L else as.integer(stat(sock, "pipes")),
       daemons = if (length(envir[["sockc"]])) query_status(envir) else if (length(envir[["urls"]])) envir[["urls"]] else 0L)

}

# internals --------------------------------------------------------------------

req_socket <- function(url, tls = NULL, resend = .intmax)
  `opt<-`(socket(protocol = "req", listen = url, tls = tls), "req:resend-time", resend)

parse_dots <- function(...)
  if (missing(...)) "" else {
    dots <- list(...)
    for (dot in dots)
      is.numeric(dot) || is.logical(dot) || stop(.messages[["wrong_dots"]])
    dnames <- names(dots)
    dots <- strcat(",", paste(dnames, dots, sep = "=", collapse = ","))
    "output" %in% dnames && return(`class<-`(dots, "output"))
    dots
  }

parse_tls <- function(tls)
  switch(length(tls) + 1L,
         "",
         sprintf(",tls='%s'", tls),
         sprintf(",tls=c('%s','%s')", tls[1L], tls[2L]))

write_args <- function(dots, rs = NULL, tls = NULL, libpath = NULL)
  shQuote(switch(length(dots),
                 sprintf("mirai::.daemon('%s')", dots[[1L]]),
                 sprintf("mirai::daemon('%s'%s%s)", dots[[1L]], dots[[2L]], parse_tls(tls)),
                 sprintf("mirai::daemon('%s'%s%s,rs=c(%s))", dots[[1L]], dots[[2L]], parse_tls(tls), paste0(dots[[3L]], collapse = ",")),
                 sprintf(".libPaths(c('%s',.libPaths()));mirai::dispatcher('%s',n=%d,rs=c(%s),monitor='%s'%s)", libpath, dots[[1L]], dots[[3L]], paste0(rs, collapse= ","), dots[[4L]], dots[[2L]]),
                 sprintf(".libPaths(c('%s',.libPaths()));mirai::dispatcher('%s',c('%s'),n=%d,monitor='%s'%s)", libpath, dots[[1L]], paste0(dots[[3L]], collapse = "','"), dots[[4L]], dots[[5L]], dots[[2L]])))

launch_daemon <- function(..., rs = NULL, tls = NULL) {
  dots <- list(...)
  dlen <- length(dots)
  output <- dlen > 1L && is.object(dots[[2L]])
  libpath <- if (dlen > 3L) (lp <- .libPaths())[file.exists(file.path(lp, "mirai"))][1L]
  system2(command = .command, args = c(if (length(libpath)) "--vanilla", "-e", write_args(dots, rs = rs, tls = tls, libpath = libpath)), stdout = if (output) "", stderr = if (output) "", wait = FALSE)
}

launch_and_sync_daemon <- function(sock, ..., rs = NULL, tls = NULL, pass = NULL) {
  cv <- cv()
  pipe_notify(sock, cv = cv, add = TRUE, remove = FALSE, flag = TRUE)
  if (is.character(tls)) {
    switch(
      length(tls),
      {
        on.exit(Sys.unsetenv("MIRAI_TEMP_FIELD1"))
        Sys.setenv(MIRAI_TEMP_FIELD1 = tls)
        Sys.unsetenv("MIRAI_TEMP_FIELD2")
      },
      {
        on.exit(Sys.unsetenv(c("MIRAI_TEMP_FIELD1", "MIRAI_TEMP_FIELD2")))
        Sys.setenv(MIRAI_TEMP_FIELD1 = tls[1L])
        Sys.setenv(MIRAI_TEMP_FIELD2 = tls[2L])
      }
    )
    if (is.character(pass)) {
      on.exit(Sys.unsetenv("MIRAI_TEMP_VAR"), add = TRUE)
      Sys.setenv(MIRAI_TEMP_VAR = pass)
    }
  }
  launch_daemon(..., rs = rs)
  until(cv, .timelimit) && stop(if (...length() < 3L) .messages[["sync_timeout"]] else .messages[["sync_dispatch"]])
}

create_stream <- function(n, seed, envir) {
  rexp(n = 1L)
  oseed <- .GlobalEnv[[".Random.seed"]]
  RNGkind("L'Ecuyer-CMRG")
  if (length(seed)) set.seed(seed)
  `[[<-`(envir, "stream", .GlobalEnv[[".Random.seed"]])
  `[[<-`(.GlobalEnv, ".Random.seed", oseed)
}
