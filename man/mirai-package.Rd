% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/mirai-package.R
\docType{package}
\encoding{UTF-8}
\name{mirai-package}
\alias{mirai-package}
\title{mirai: Minimalist Async Evaluation Framework for R}
\description{
Lightweight parallel code execution and distributed computing. Designed for
    simplicity, a 'mirai' evaluates an R expression asynchronously, on local
    or network resources, resolving automatically upon completion. Features
    efficient task scheduling, fast inter-process communications, and
    Transport Layer Security over TCP/IP for remote connections, courtesy of
    'nanonext' and 'NNG' (Nanomsg Next Gen).
}
\section{Notes}{


    For local mirai requests, the default transport for inter-process
    communications is platform-dependent: abstract Unix domain sockets on
    Linux, Unix domain sockets on MacOS, Solaris and other POSIX platforms,
    and named pipes on Windows.

    This may be overriden, if required, by specifying 'url' in the
    \code{\link{daemons}} interface and launching daemons using
    \code{\link{launch_local}}.
}

\section{Links}{


    mirai website: \url{https://shikokuchuo.net/mirai/}\cr
    mirai on CRAN: \url{https://cran.r-project.org/package=mirai}

    nanonext website: \url{https://shikokuchuo.net/nanonext/}\cr
    nanonext on CRAN: \url{https://cran.r-project.org/package=nanonext}

    NNG website: \url{https://nng.nanomsg.org/}
}

\author{
Charlie Gao \email{charlie.gao@shikokuchuo.net}
    (\href{https://orcid.org/0000-0002-0750-061X}{ORCID})
}
