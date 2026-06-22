
spec_to_lavaan <- function(spec) {
    nodes <- spec$nodes
    edges <- spec$edges

    if (length(nodes) == 0 || length(edges) == 0) return(NULL)

    nodeMap <- stats::setNames(
        lapply(nodes, function(n) n),
        sapply(nodes, function(n) n$id)
    )

    labelToSafe <- list()
    safeToLabel <- list()
    safeIdx     <- 0L
    for (n in nodes) {
        lbl <- n$label
        if (!grepl("^[A-Za-z][A-Za-z0-9._]*$", lbl)) {
            safeIdx <- safeIdx + 1L
            prefix <- if (identical(n$type, "latent")) "LVSEM" else "OBSEM"
            safe <- paste0(prefix, safeIdx)
            labelToSafe[[lbl]] <- safe
            safeToLabel[[safe]] <- lbl
        }
    }

    sn <- function(node) {
        lbl <- node$label
        if (!is.null(labelToSafe[[lbl]])) labelToSafe[[lbl]] else lbl
    }

    constrain <- function(term, edge) {
        cv <- if (!is.null(edge$constraint)) trimws(as.character(edge$constraint)) else ""
        if (!nzchar(cv)) return(term)
        if (!suppressWarnings(is.finite(as.numeric(cv))))
            jmvcore::reject(paste0(.("Invalid constraint value: '"), cv, .("' — must be a number.")))
        paste0(cv, "*", term)
    }

    loadings    <- list()
    regressions <- list()
    covariances <- character(0)

    for (edge in edges) {
        fromNode <- nodeMap[[edge$from]]
        toNode   <- nodeMap[[edge$to]]
        if (is.null(fromNode) || is.null(toNode)) next

        fl <- sn(fromNode)
        tl <- sn(toNode)

        if (edge$type == "loading") {
            if (is.null(loadings[[fl]])) loadings[[fl]] <- character(0)
            loadings[[fl]] <- c(loadings[[fl]], constrain(tl, edge))

        } else if (edge$type == "regression") {
            if (identical(fromNode$type, "latent") && identical(toNode$type, "observed")) {
                if (is.null(loadings[[fl]])) loadings[[fl]] <- character(0)
                loadings[[fl]] <- c(loadings[[fl]], constrain(tl, edge))
            } else {
                if (is.null(regressions[[tl]])) regressions[[tl]] <- character(0)
                regressions[[tl]] <- c(regressions[[tl]], constrain(fl, edge))
            }

        } else if (edge$type == "covariance") {
            if (fromNode$label != toNode$label) {
                covariances <- c(covariances, paste0(fl, " ~~ ", constrain(tl, edge)))
            }
        }
    }

    lines <- character(0)
    for (lhs in names(loadings)) {
        lines <- c(lines, paste0(lhs, " =~ ", paste(loadings[[lhs]], collapse = " + ")))
    }
    for (lhs in names(regressions)) {
        lines <- c(lines, paste0(lhs, " ~ ", paste(regressions[[lhs]], collapse = " + ")))
    }
    lines <- c(lines, covariances)

    if (length(lines) == 0) return(NULL)
    list(syntax = paste(lines, collapse = "\n"), safeToLabel = safeToLabel, labelToSafe = labelToSafe)
}
