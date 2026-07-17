
# This file is a generated template, your changes will not be overwritten


PathfyClass <- if (requireNamespace('jmvcore', quietly=TRUE)) R6::R6Class(
    "PathfyClass",
    inherit = PathfyBase,
    private = list(

        # Cache of the last successful fit, keyed on a signature that excludes
        # cosmetic-only fields (node x/y, residualDir) so that dragging a node
        # in the diagram does not force a full lavaan re-fit.
        .cacheSig       = NULL,
        .cacheFit       = NULL,
        .cacheEstimates = NULL,
        .cacheSafeToLabel = NULL,
        .cacheLabelToSafe = NULL,
        .cacheLavaanModel = NULL,
        .cacheLatentLabels = NULL,

        .run = function() {

            vars       <- self$options$vars
            modelSpec  <- self$options$modelSpec
            latentVars <- self$options$latentVars

            estimates <- NULL

            # Detect FIML fallback (FIML selected but estimator doesn't support it)
            fimlFallback <- self$options$missing == "fiml" &&
                            !(toupper(self$options$estimator) %in% c("ML", "MLR", "MLM"))
            canvasNote <- if (fimlFallback)
                .("Missing data: Listwise deletion (Full Information ML is not available with this estimator)")
            else ""

            rendered <- FALSE
            renderNow <- function(est) {
                private$.renderEditor(vars, modelSpec, latentVars, est, canvasNote)
                rendered <<- TRUE
            }

            if (length(vars) > 0) {
                spec <- tryCatch(
                    jsonlite::fromJSON(modelSpec, simplifyVector = FALSE),
                    error = function(e) NULL
                )

                if (!is.null(spec) && length(spec$edges) > 0) {
                    lavaanResult <- private$.specToLavaan(spec)

                    if (!is.null(lavaanResult)) {
                        lavaanModel <- lavaanResult$syntax
                        safeToLabel <- lavaanResult$safeToLabel
                        labelToSafe <- lavaanResult$labelToSafe

                        # Validate: latent variables used in paths must have loadings
                        latentNodes <- Filter(function(n) identical(n$type, "latent"), spec$nodes)
                        for (lNode in latentNodes) {
                            lid <- lNode$id
                            hasLoading   <- any(sapply(spec$edges, function(e) e$type == "loading" && (e$from == lid || e$to == lid)))
                            usedInPath   <- any(sapply(spec$edges, function(e) e$type != "loading" && (e$from == lid || e$to == lid)))
                            if (!hasLoading && usedInPath) {
                                renderNow(NULL)
                                jmvcore::reject(sprintf(
                                    .("Latent variable '%s' has no indicators. Add at least one loading before using it in a path."),
                                    lNode$label
                                ))
                            }
                        }

                        data <- self$data
                        # Rename non-ASCII observed variable columns to safe proxy names
                        if (length(labelToSafe) > 0) {
                            obsRename <- intersect(names(labelToSafe), names(data))
                            if (length(obsRename) > 0)
                                names(data)[match(obsRename, names(data))] <- unlist(labelToSafe[obsRename])
                        }

                        # Check for factor variables (only continuous/numeric is supported)
                        obsNodes <- Filter(function(n) identical(n$type, "observed"), spec$nodes)
                        for (oNode in obsNodes) {
                            col <- if (!is.null(labelToSafe[[oNode$label]])) labelToSafe[[oNode$label]] else oNode$label
                            if (col %in% names(data) && is.factor(data[[col]])) {
                                renderNow(NULL)
                                jmvcore::reject(sprintf(
                                    .("Only continuous (numeric) variables can be used. '%s' is a categorical variable."),
                                    oNode$label
                                ))
                            }
                        }

                        estimator <- toupper(self$options$estimator)
                        missing   <- self$options$missing
                        # FIML is only supported with ML-family estimators
                        if (missing == "fiml" && !(estimator %in% c("ML", "MLR", "MLM")))
                            missing <- "listwise"
                        std.lv    <- self$options$identification == "variance"

                        # Structural signature: excludes cosmetic fields (x, y, residualDir)
                        # so dragging a node in the diagram doesn't force a lavaan re-fit.
                        structSig <- list(
                            nodes = lapply(spec$nodes, function(n) list(id = n$id, label = n$label, type = n$type)),
                            edges = lapply(spec$edges, function(e) list(from = e$from, to = e$to, type = e$type, constraint = e$constraint)),
                            estimator = estimator,
                            missing = missing,
                            std.lv = std.lv,
                            ci = self$options$ci,
                            ciWidth = self$options$ciWidth,
                            dataSig = list(
                                nrow = nrow(data),
                                names = names(data),
                                sums = vapply(data, function(col)
                                    if (is.numeric(col)) sum(col, na.rm = TRUE) else length(unique(col)),
                                    numeric(1))
                            )
                        )

                        if (!is.null(private$.cacheFit) && identical(structSig, private$.cacheSig)) {
                            fit         <- private$.cacheFit
                            estimates   <- private$.cacheEstimates
                            safeToLabel <- private$.cacheSafeToLabel
                            latentLabels <- private$.cacheLatentLabels
                        } else {
                            # Render before the (uncached) fit attempt, in case it errors or
                            # fails to converge, so the diagram stays up-to-date under the error banner
                            renderNow(NULL)

                            fit <- tryCatch(
                                lavaan::sem(
                                    model     = lavaanModel,
                                    data      = data,
                                    estimator = estimator,
                                    missing   = missing,
                                    std.lv    = std.lv
                                ),
                                error = function(e) e
                            )

                            if (inherits(fit, "error")) {
                                jmvcore::reject(paste0(.("lavaan error: "), conditionMessage(fit)))
                            } else if (!lavaan::lavInspect(fit, "converged")) {
                                jmvcore::reject(.("Model did not converge. Check model identification."))
                            }

                            estimates <- lavaan::parameterEstimates(
                                fit,
                                standardized = TRUE,
                                ci           = self$options$ci,
                                level        = self$options$ciWidth / 100
                            )
                            # Reverse-map ASCII proxies back to original (e.g. Japanese) labels
                            if (length(safeToLabel) > 0) {
                                mapBack <- function(x) {
                                    sapply(x, function(v) {
                                        if (!is.null(safeToLabel[[v]])) safeToLabel[[v]] else v
                                    }, USE.NAMES = FALSE)
                                }
                                estimates$lhs <- mapBack(estimates$lhs)
                                estimates$rhs <- mapBack(estimates$rhs)
                            }
                            latentLabels <- sapply(
                                Filter(function(n) identical(n$type, "latent"), spec$nodes),
                                function(n) n$label
                            )

                            private$.cacheSig         <- structSig
                            private$.cacheFit         <- fit
                            private$.cacheEstimates   <- estimates
                            private$.cacheSafeToLabel <- safeToLabel
                            private$.cacheLabelToSafe <- labelToSafe
                            private$.cacheLavaanModel <- lavaanModel
                            private$.cacheLatentLabels <- latentLabels
                        }

                        renderNow(estimates)
                        private$.populateFit(fit)
                        private$.populateParameters(fit, estimates, latentLabels)
                        if (isTRUE(self$options$modIndices))
                            private$.populateModIndices(fit, safeToLabel)
                        if (isTRUE(self$options$residCov))
                            private$.populateResidCov(fit, safeToLabel)
                        if (isTRUE(self$options$showSyntax)) {
                            header <- ""
                            if (length(safeToLabel) > 0) {
                                mapping <- paste(
                                    sapply(names(safeToLabel), function(s)
                                        paste0("# ", s, ' = "', safeToLabel[[s]], '"')),
                                    collapse = "\n"
                                )
                                note <- .("Non-ASCII variable names are replaced as above to prevent lavaan errors.")
                                header <- paste0(mapping, "\n# ", note, "\n\n")
                            }
                            full_text <- paste0(header, lavaanModel)
                            escaped <- gsub("&", "&amp;", full_text, fixed = TRUE)
                            escaped <- gsub("<", "&lt;",  escaped,   fixed = TRUE)
                            self$results$lavaanCode$setContent(
                                paste0('<pre style="font-family:monospace;font-size:13px;',
                                       'padding:8px;background:#f8f8f8;',
                                       'border:1px solid #ddd;border-radius:4px;">',
                                       escaped, '</pre>')
                            )
                        }
                    }
                }
            }

            if (!rendered) renderNow(NULL)
        },

        # JSON model spec → lavaan syntax (delegates to standalone spec_to_lavaan())
        .specToLavaan = function(spec) {
            spec_to_lavaan(spec)
        },

        # Model fit tables (CFA-style: separate test and fit measures tables)
        .populateFit = function(fit) {
            opts <- self$options
            fm   <- lavaan::fitMeasures(fit)

            if (opts$fitChiSq) {
                self$results$modelFit$test$setRow(rowNo = 1, values = list(
                    chi = as.numeric(fm["chisq"]),
                    df  = as.integer(fm["df"]),
                    p   = as.numeric(fm["pvalue"])
                ))
            }

            if (opts$fitCFI || opts$fitTLI || opts$fitSRMR ||
                opts$fitRMSEA || opts$fitAIC || opts$fitBIC) {
                self$results$modelFit$fitMeasures$setRow(rowNo = 1, values = list(
                    cfi        = as.numeric(fm["cfi"]),
                    tli        = as.numeric(fm["tli"]),
                    srmr       = as.numeric(fm["srmr"]),
                    rmsea      = as.numeric(fm["rmsea"]),
                    rmseaLower = as.numeric(fm["rmsea.ci.lower"]),
                    rmseaUpper = as.numeric(fm["rmsea.ci.upper"]),
                    aic        = as.numeric(fm["aic"]),
                    bic        = as.numeric(fm["bic"])
                ))
            }
        },

        # Parameter estimates table
        .populateParameters = function(fit, pe = NULL, latentLabels = character(0)) {
            opts <- self$options
            if (is.null(pe)) {
                pe <- lavaan::parameterEstimates(
                    fit,
                    standardized = opts$std,
                    ci           = opts$ci,
                    level        = opts$ciWidth / 100
                )
            }

            lat_names <- lavaan::lavNames(fit, type = "lv")
            tbl <- self$results$parameters
            if (isTRUE(opts$ci)) {
                ciLabel <- paste0(opts$ciWidth, "% CI")
                tbl$getColumn("ciLower")$setSuperTitle(ciLabel)
                tbl$getColumn("ciUpper")$setSuperTitle(ciLabel)
            }

            for (i in seq_len(nrow(pe))) {
                row <- pe[i, ]
                op  <- as.character(row$op)
                lhs <- as.character(row$lhs)
                rhs <- as.character(row$rhs)

                show <- if (op %in% c("=~", "~")) {
                    TRUE
                } else if (op == "~~") {
                    if (lhs == rhs) isTRUE(opts$showResiduals) else TRUE
                } else if (op == "~1") {
                    FALSE
                } else {
                    TRUE
                }

                if (!show) next

                opDisplay <- switch(op,
                    "=~" = "->",
                    "~"  = "->",
                    "~~" = if (lhs == rhs) .("var") else "<->",
                    "~1" = .("mean"),
                    op
                )

                # For regressions, lavaan's lhs is the outcome and rhs is the
                # predictor, so the displayed arrow direction must be reversed
                # (predictor -> outcome) relative to loadings (latent -> indicator).
                dispLhs <- if (op == "~") rhs else lhs
                dispRhs <- if (op == "~") lhs else rhs

                tbl$addRow(rowKey=i, values=list(
                    label   = if (!is.null(row$label) && !is.na(row$label)) as.character(row$label) else "",
                    lhs     = dispLhs,
                    op      = opDisplay,
                    rhs     = dispRhs,
                    est     = as.numeric(row$est),
                    se      = as.numeric(row$se),
                    z       = as.numeric(row$z),
                    p       = as.numeric(row$pvalue),
                    ciLower = if ("ci.lower" %in% names(pe)) as.numeric(row$ci.lower) else NA_real_,
                    ciUpper = if ("ci.upper" %in% names(pe)) as.numeric(row$ci.upper) else NA_real_,
                    stdAll  = if ("std.all"  %in% names(pe)) as.numeric(row$std.all)  else NA_real_
                ))
            }
        },

        # Modification indices table
        .populateModIndices = function(fit, safeToLabel = list()) {
            threshold <- self$options$modIndicesThreshold
            mi <- tryCatch(
                lavaan::modificationIndices(fit, sort. = TRUE),
                error = function(e) NULL
            )
            if (is.null(mi) || nrow(mi) == 0) return()

            mi <- mi[mi$mi >= threshold, , drop = FALSE]
            if (nrow(mi) == 0) return()

            mapBack <- function(x) {
                sapply(x, function(v) {
                    if (!is.null(safeToLabel[[v]])) safeToLabel[[v]] else v
                }, USE.NAMES = FALSE)
            }
            mi$lhs <- mapBack(mi$lhs)
            mi$rhs <- mapBack(mi$rhs)

            tbl <- self$results$modIndices
            for (i in seq_len(nrow(mi))) {
                row <- mi[i, ]
                op  <- as.character(row$op)
                opDisplay <- switch(op,
                    "=~" = "->", "~" = "->", "~~" = "<->", op)
                lhs <- as.character(row$lhs)
                rhs <- as.character(row$rhs)
                dispLhs <- if (op == "~") rhs else lhs
                dispRhs <- if (op == "~") lhs else rhs
                tbl$addRow(rowKey = i, values = list(
                    lhs = dispLhs,
                    op  = opDisplay,
                    rhs = dispRhs,
                    mi  = as.numeric(row$mi),
                    epc = as.numeric(row$epc)
                ))
            }
        },

        # Residual correlation matrix
        .populateResidCov = function(fit, safeToLabel = list()) {
            threshold <- self$options$residCovThreshold
            res <- tryCatch(
                lavaan::residuals(fit, type = "cor")$cov,
                error = function(e) NULL
            )
            if (is.null(res) || nrow(res) == 0) return()

            mapBack <- function(x) {
                sapply(x, function(v) {
                    if (!is.null(safeToLabel[[v]])) safeToLabel[[v]] else v
                }, USE.NAMES = FALSE)
            }
            rownames(res) <- mapBack(rownames(res))
            colnames(res) <- mapBack(colnames(res))

            vars <- rownames(res)
            tbl  <- self$results$residCov

            for (v in vars)
                tbl$addColumn(name = v, title = v, type = "number", format = "zto")

            for (i in seq_along(vars)) {
                values <- list(var = vars[i])
                for (j in seq_along(vars)) {
                    values[[vars[j]]] <- if (j < i) as.numeric(res[i, j]) else NA_real_
                }
                tbl$addRow(rowKey = i, values = values)
                for (j in seq_len(i - 1)) {
                    if (!is.na(res[i, j]) && abs(res[i, j]) >= threshold)
                        tbl$addFormat(rowKey = i, col = vars[j], jmvcore::Cell.NEGATIVE)
                }
            }
        },

        # Render the HTML path diagram editor
        .renderEditor = function(vars, modelSpec, latentVars = "", estimates = NULL, note = "") {
            # Escape <, >, & so injected JSON cannot break out of <script> blocks
            jsEscape <- function(s) {
                s <- gsub("&", "\\u0026", s, fixed = TRUE)
                s <- gsub("<", "\\u003c", s, fixed = TRUE)
                s <- gsub(">", "\\u003e", s, fixed = TRUE)
                s
            }

            varsJson <- jsEscape(jsonlite::toJSON(as.character(vars), auto_unbox = FALSE))

            latentNames <- character(0)
            if (length(latentVars) > 0) {
                latentNames <- trimws(unlist(latentVars))
                latentNames <- latentNames[nchar(latentNames) > 0]
            }
            latentJson <- jsEscape(jsonlite::toJSON(latentNames, auto_unbox = FALSE))

            # Parameter estimates for diagram display
            if (!is.null(estimates)) {
                cols <- intersect(c("lhs","op","rhs","est","se","z","pvalue","std.all"),
                                  names(estimates))
                estimatesJson <- jsEscape(jsonlite::toJSON(
                    estimates[, cols, drop = FALSE],
                    auto_unbox = FALSE, na = "null"
                ))
            } else {
                estimatesJson <- "[]"
            }

            showStd       <- if (isTRUE(self$options$std))          "true" else "false"
            hideResiduals <- if (isTRUE(self$options$showResiduals)) "false" else "true"

            html <- .EDITOR_HTML
            html <- gsub("%%VARS%%",            varsJson,             html, fixed = TRUE)
            html <- gsub("%%MODEL_SPEC%%",       jsEscape(modelSpec),  html, fixed = TRUE)
            html <- gsub("%%LATENT_VARS%%",      latentJson,           html, fixed = TRUE)
            html <- gsub("%%PARAM_ESTIMATES%%",  estimatesJson,        html, fixed = TRUE)
            html <- gsub("%%SHOW_STD%%",         showStd,       html, fixed = TRUE)
            html <- gsub("%%HIDE_RESIDUALS%%",   hideResiduals, html, fixed = TRUE)

            # Toolbar labels
            html <- gsub("%%LABEL_LAYOUT%%",        .("Auto Layout"),                        html, fixed = TRUE)
            html <- gsub("%%LABEL_SHOW_EST%%",      .("Estimates"),                          html, fixed = TRUE)
            html <- gsub("%%LABEL_HINT_RIGHTCLICK%%", .("Right-click a node to add paths"), html, fixed = TRUE)

            # Right-click menu labels (node and error node)
            html <- gsub("%%LABEL_FIX_VALUE%%",         .("Fix value..."),      html, fixed = TRUE)
            html <- gsub("%%LABEL_FIX_PARAM_TITLE%%",   .("Fix parameter"),     html, fixed = TRUE)
            html <- gsub("%%LABEL_FIX_PARAM_ERR%%",     .("Enter a number."),   html, fixed = TRUE)
            html <- gsub("%%LABEL_REMOVE_CONSTRAINT%%",  .("Remove constraint"), html, fixed = TRUE)
            html <- gsub("%%LABEL_ADD_LOADING%%",    .("Add Loading"),    html, fixed = TRUE)
            html <- gsub("%%LABEL_ADD_REGRESSION%%", .("Add Regression"), html, fixed = TRUE)
            html <- gsub("%%LABEL_ADD_COVARIANCE%%", .("Add Covariance"), html, fixed = TRUE)
            html <- gsub("%%LABEL_DELETE%%",         .("Delete"),         html, fixed = TRUE)
            html <- gsub("%%LABEL_ERR_TOP%%",    .("Error above"), html, fixed = TRUE)
            html <- gsub("%%LABEL_ERR_BOTTOM%%", .("Error below"), html, fixed = TRUE)
            html <- gsub("%%LABEL_ERR_LEFT%%",   .("Error left"),  html, fixed = TRUE)
            html <- gsub("%%LABEL_ERR_RIGHT%%",  .("Error right"), html, fixed = TRUE)

            # Modal labels
            html <- gsub("%%LABEL_OK%%",           .("OK"),                              html, fixed = TRUE)
            html <- gsub("%%LABEL_CANCEL%%",       .("Cancel"),                          html, fixed = TRUE)
            html <- gsub("%%LABEL_EDIT_NAME%%",    .("Edit variable name"),              html, fixed = TRUE)
            html <- gsub("%%LABEL_NAME_CONFLICT%%", .("Name already used as observed variable."), html, fixed = TRUE)

            html <- gsub("%%CANVAS_NOTE_DISPLAY%%", if (nzchar(note)) "block" else "none", html, fixed = TRUE)
            html <- gsub("%%CANVAS_NOTE%%",         note,                                   html, fixed = TRUE)

            self$results$diagram$setContent(html)
        }
    )
)
