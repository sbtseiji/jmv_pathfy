
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
            jmvcore::reject(jmvcore::format(
                .("Invalid constraint value: '{value}' — must be a number."), value = cv))
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
            if (is.null(regressions[[tl]])) regressions[[tl]] <- character(0)
            regressions[[tl]] <- c(regressions[[tl]], constrain(fl, edge))

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

    undrawn <- undrawn_covariances(paste(lines, collapse = "\n"))
    lines <- c(lines, undrawn$lines)

    originalLabels <- function(pairs) lapply(pairs, function(pair)
        vapply(pair, function(v)
            if (!is.null(safeToLabel[[v]])) safeToLabel[[v]] else v,
            character(1), USE.NAMES = FALSE))

    list(
        syntax       = paste(lines, collapse = "\n"),
        safeToLabel  = safeToLabel,
        labelToSafe  = labelToSafe,
        uncorrelated = originalLabels(undrawn$uncorrelated),
        uncorrelatedResiduals = originalLabels(undrawn$uncorrelatedResiduals)
    )
}

# Covariances that are not drawn in the diagram but that lavaan::sem() would
# add on its own (between exogenous latent variables, and between the
# residuals of outcomes that predict nothing else). Each is returned as a
# `lhs ~~ 0*rhs` line, so the syntax alone, run through a default sem() call,
# fits the model as drawn. lavaan itself is asked which covariances it would
# add, rather than re-deriving its rules here: a pair missed by a hand-written
# rule would silently be estimated.
#
# `uncorrelated` lists the pairs of exogenous latent variables among them and
# `uncorrelatedResiduals` the remaining pairs (residuals of outcomes); the
# caller reports both to the user.
undrawn_covariances <- function(syntax) {
    none <- list(lines = character(0), uncorrelated = list(), uncorrelatedResiduals = list())

    # Same auto.* defaults as lavaan::sem(). A syntax lavaan cannot parse is
    # left as is, so that the error is reported by the fit itself.
    pt <- tryCatch(
        lavaan::lavaanify(
            syntax,
            int.ov.free     = TRUE,
            int.lv.free     = FALSE,
            auto.fix.first  = TRUE,
            auto.fix.single = TRUE,
            auto.var        = TRUE,
            auto.cov.lv.x   = TRUE,
            auto.cov.y      = TRUE,
            auto.th         = TRUE,
            auto.delta      = TRUE,
            auto.efa        = TRUE,
            fixed.x         = TRUE,
            warn            = FALSE
        ),
        error = function(e) NULL
    )
    if (is.null(pt)) return(none)

    # exo == 1 marks covariances among observed predictors, which sem() fixes
    # to their sample values (fixed.x) instead of estimating; those stay.
    auto <- pt[pt$op == "~~" & pt$lhs != pt$rhs & pt$user == 0 & pt$exo == 0, , drop = FALSE]
    if (nrow(auto) == 0) return(none)

    latent    <- unique(pt$lhs[pt$op == "=~"])
    dependent <- unique(c(pt$lhs[pt$op == "~"], pt$rhs[pt$op == "=~"]))
    exoLatent <- setdiff(latent, dependent)
    isUncorrelated <- auto$lhs %in% exoLatent & auto$rhs %in% exoLatent

    pairs <- function(rows) Map(c, auto$lhs[rows], auto$rhs[rows], USE.NAMES = FALSE)

    list(
        lines        = paste0(auto$lhs, " ~~ 0*", auto$rhs),
        uncorrelated = pairs(isUncorrelated),
        uncorrelatedResiduals = pairs(!isUncorrelated)
    )
}
