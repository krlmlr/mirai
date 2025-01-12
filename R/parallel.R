# Copyright (C) 2023 Hibiki AI Limited <info@hibiki-ai.com>
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

# mirai x parallel -------------------------------------------------------------

# nocov start
# tested manually in tests/parallel/parallel-tests.R

#' Make Mirai Cluster
#'
#' \code{make_cluster} creates a cluster of type 'miraiCluster', which may be
#'     used as a cluster object for any function in the \pkg{parallel} base
#'     package such as \code{\link[parallel]{clusterApply}} or
#'     \code{\link[parallel]{parLapply}}.
#'
#' @inheritParams launch_remote
#' @param n integer number of nodes (launched on the local machine unless 'url'
#'     is specified).
#' @param url (specify for remote nodes), the character URL on the host for
#'     remote nodes to dial into, including a port accepting incoming connections,
#'     e.g. 'tcp://10.75.37.40:5555'. Specify a URL starting 'tls+tcp://' to use
#'     secure TLS connections.
#' @param ... additional arguments passed onto \code{\link{daemons}}.
#' @param rscript (for remote only) name / path of the Rscript executable on
#'     the remote machine. The default assumes 'Rscript' is on the executable
#'     search path. Prepend the full path if necessary. If launching on Windows,
#'     'Rscript' should be replaced with 'Rscript.exe'.
#'
#' @return For \strong{make_cluster}: An object of class 'miraiCluster' and
#'     'cluster'. Each 'miraiCluster' has an automatically assigned ID and 'n'
#'     nodes of class 'miraiNode'.
#'
#'     For \strong{stop_cluster}: invisible NULL.
#'
#' @details The default behaviour of clusters created by this function is
#'     designed to map as closely as possible to clusters created by the
#'     \pkg{parallel} package. However, '...' arguments are passed onto
#'     \code{\link{daemons}} for additional customisation if desired.
#'
#'     Call \code{\link{status}} on a 'miraiCluster' to check the number of
#'     currently active connections as well as the host URL.
#'
#' @section Remote Nodes:
#'
#'     For remote nodes, the arguments 'command', 'args' and 'rscript' map
#'     directly to the relevant arguments of \code{\link{launch_remote}}.
#'
#'     If launching remote nodes, the number of nodes is inferred from the length
#'     of 'args', and 'n' is disregarded if supplied. The auxiliary function
#'     \code{\link{ssh_args}} may be used to construct the required arguments to
#'     use SSH as a launcher, both with and without tunnelling.
#'
#'     Alternatively, by specifying only 'url' and 'n', the host connection
#'     listening at 'url' is set up, and nodes may be launched by other custom
#'     means.
#'
#' @note Requires R >= 4.4 (currently R-devel). Clusters created with this
#'     function will not work with prior R versions. The functionality is
#'     experimental prior to release of R 4.4 and the interface is consequently
#'     subject to change at any time.
#'
#' @examples
#' if (interactive()) {
#' # Only run examples in interactive R sessions
#'
#' cl <- make_cluster(2)
#' cl
#' cl[[1L]]
#'
#' Sys.sleep(0.5)
#' status(cl)
#'
#' stop_cluster(cl)
#'
#' }
#'
#' @export
#'
make_cluster <- function(n, url = NULL, ..., command = NULL, args = c("", "."), rscript = "Rscript") {

  id <- sprintf("`%d`", length(..))

  if (is.character(url)) {

    length(url) == 1L || stop(.messages[["single_url"]])

    if (length(command)) {
      daemons(url = url, dispatcher = FALSE, resilience = FALSE, cleanup = 0L, ..., .compute = id)
      launch_remote(url = url, .compute = id, command = command, args = args, rscript = rscript)
      n <- if (is.list(args)) length(args) else 1L

    } else {
      missing(n) && stop(.messages[["requires_n"]])
      daemons(url = url, dispatcher = FALSE, resilience = FALSE, cleanup = 0L, ..., .compute = id)
      message(sprintf("%d nodes connecting to '%s' should be launched manually", n, url))
    }

  } else {
    missing(n) && stop(.messages[["missing_url"]])
    is.numeric(n) || stop(.messages[["numeric_n"]])
    daemons(n = n, dispatcher = FALSE, resilience = FALSE, cleanup = 0L, ..., .compute = id)
  }

  pipe_notify(..[[id]][["sock"]], cv = ..[[id]][["cv"]], add = FALSE, remove = TRUE, flag = TRUE)

  cl <- vector(mode = "list", length = n)
  for (i in seq_along(cl))
    cl[[i]] <- `attributes<-`(new.env(), list(class = "miraiNode", node = i, id = id))
  reg.finalizer(cl[[1L]], stop_cluster, TRUE)

  `attributes<-`(cl, list(class = c("miraiCluster", "cluster"), id = id))

}

#' Stop Mirai Cluster
#'
#' \code{stop_cluster} stops a cluster created by \code{make_cluster}.
#'
#' @param cl a 'miraiCluster'.
#'
#' @rdname make_cluster
#' @export
#'
stop_cluster <- function(cl) {

  daemons(0L, .compute = attr(cl, "id"))
  invisible()

}

#' @method stopCluster miraiCluster
#' @export
#'
stopCluster.miraiCluster <- stop_cluster

#' @method sendData miraiNode
#' @export
#'
sendData.miraiNode <- function(node, data) {

  length(..[[attr(node, "id")]]) || stop(.messages[["cluster_inactive"]])

  value <- data[["data"]]
  has_tag <- !is.null(value[["tag"]])

  node[["mirai"]] <- mirai(do.call(node, data, quote = TRUE), node = value[["fun"]], data = value[["args"]],
                           .signal = has_tag, .compute = attr(node, "id"))

  if (has_tag)
    assign("tag", value[["tag"]], node[["mirai"]])

}

#' @method recvData miraiNode
#' @export
#'
recvData.miraiNode <- function(node) call_mirai(.subset2(node, "mirai"))

#' @method recvOneData miraiCluster
#' @export
#'
recvOneData.miraiCluster <- function(cl) {

  envir <- ..[[attr(cl, "id")]]

  wait(envir[["cv"]]) || {
    stop_cluster(cl)
    stop(.messages[["nodes_failed"]])
  }

  node <- which.min(lapply(cl, node_unresolved))
  m <- .subset2(.subset2(cl, node), "mirai")
  out <- list(node = node, value = list(value = .subset2(m, "value"), tag = .subset2(m, "tag")))
  assign("value", .unresolved_marker, m)
  out

}

#' @export
#'
print.miraiCluster <- function(x, ...) {

  cat(sprintf("< miraiCluster >\n - cluster ID: %s\n - nodes: %d\n - active: %s\n",
              attr(x, "id"), length(x), as.logical(length(..[[attr(x, "id")]]))), file = stdout())
  invisible(x)

}

#' @export
#'
print.miraiNode <- function(x, ...) {

  cat(sprintf("< miraiNode >\n - node: %d\n - cluster ID: %s\n", attr(x, "node"), attr(x, "id")), file = stdout())
  invisible(x)

}

# internals --------------------------------------------------------------------

node_unresolved <- function(node) unresolved(.subset2(node, "mirai"))

# nocov end
