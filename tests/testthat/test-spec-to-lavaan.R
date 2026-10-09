# Compare generated syntax line by line: line endings are unified and runs of
# whitespace within a line collapsed, but line breaks are kept, so a test can
# still tell "one line" from "two lines".
norm_syntax <- function(x) {
    lines <- strsplit(gsub("\r\n?", "\n", x), "\n", fixed = TRUE)[[1]]
    lines <- gsub("\\s+", " ", trimws(lines))
    lines[nzchar(lines)]
}

expect_syntax <- function(actual, expected) {
    expect_equal(norm_syntax(actual), norm_syntax(expected))
}

# Free parameters of a model, as "lhs op rhs" strings
free_params <- function(model, ...) {
    pt <- lavaan::parTable(lavaan::sem(model, do.fit = FALSE, ...))
    pt <- pt[pt$free > 0, ]
    sort(paste(pt$lhs, pt$op, pt$rhs))
}

# Build a spec from "from -> to" style edge triples; node types are taken
# from `latent`.
make_spec <- function(latent, edges) {
    labels <- unique(unlist(lapply(edges, function(e) e[c(1, 3)])))
    ids <- stats::setNames(paste0("n", seq_along(labels)), labels)
    list(
        nodes = unname(lapply(labels, function(l) list(
            id = ids[[l]], label = l,
            type = if (l %in% latent) "latent" else "observed"))),
        edges = lapply(edges, function(e) list(
            from = ids[[e[1]]], to = ids[[e[3]]],
            type = switch(e[2], "=~" = "loading", "~>" = "regression", "~~" = "covariance")))
    )
}

loadings_of <- function(factor, indicators)
    lapply(indicators, function(x) c(factor, "=~", x))

hs_cfa_edges <- c(
    loadings_of("visual",  c("x1", "x2", "x3")),
    loadings_of("textual", c("x4", "x5", "x6")),
    loadings_of("speed",   c("x7", "x8", "x9"))
)
hs_factors <- c("visual", "textual", "speed")

test_that("CFA: single factor with three indicators", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "F1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "observed", label = "x2"),
            list(id = "n4", type = "observed", label = "x3")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n1", to = "n3", type = "loading"),
            list(from = "n1", to = "n4", type = "loading")
        )
    )
    result <- spec_to_lavaan(spec)
    expect_syntax(result$syntax, "F1 =~ x1 + x2 + x3")
    expect_equal(length(result$safeToLabel), 0)
})

test_that("Two-factor CFA produces two loading lines", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "F1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "observed", label = "x2"),
            list(id = "n4", type = "latent",   label = "F2"),
            list(id = "n5", type = "observed", label = "y1"),
            list(id = "n6", type = "observed", label = "y2")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n1", to = "n3", type = "loading"),
            list(from = "n4", to = "n5", type = "loading"),
            list(from = "n4", to = "n6", type = "loading")
        )
    )
    result <- spec_to_lavaan(spec)
    lines <- norm_syntax(result$syntax)
    expect_true(any(grepl("^F1 =~ x1 \\+ x2$", lines)))
    expect_true(any(grepl("^F2 =~ y1 \\+ y2$", lines)))
})

test_that("Observed regression path", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "observed", label = "x1"),
            list(id = "n2", type = "observed", label = "y1")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "regression")
        )
    )
    result <- spec_to_lavaan(spec)
    expect_syntax(result$syntax, "y1 ~ x1")
})

test_that("Latent-to-latent structural path", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "F1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "latent",   label = "F2"),
            list(id = "n4", type = "observed", label = "y1")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n3", to = "n4", type = "loading"),
            list(from = "n1", to = "n3", type = "regression")
        )
    )
    result <- spec_to_lavaan(spec)
    lines <- norm_syntax(result$syntax)
    expect_true(any(grepl("^F2 ~ F1$", lines)))
})

test_that("Latent-to-observed regression stays a regression, not a loading", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "F1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "observed", label = "x2"),
            list(id = "n4", type = "observed", label = "y1")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n1", to = "n3", type = "loading"),
            list(from = "n1", to = "n4", type = "regression")
        )
    )
    result <- spec_to_lavaan(spec)
    expect_syntax(result$syntax, "F1 =~ x1 + x2\ny1 ~ F1")
})

test_that("Covariance between two latent factors", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "F1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "latent",   label = "F2"),
            list(id = "n4", type = "observed", label = "y1")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n3", to = "n4", type = "loading"),
            list(from = "n1", to = "n3", type = "covariance")
        )
    )
    result <- spec_to_lavaan(spec)
    expect_true(grepl("F1 ~~ F2", result$syntax))
})

test_that("Fixed constraint generates value* prefix", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "F1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "latent",   label = "F2"),
            list(id = "n4", type = "observed", label = "y1")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n3", to = "n4", type = "loading"),
            list(from = "n1", to = "n3", type = "covariance", constraint = "0")
        )
    )
    result <- spec_to_lavaan(spec)
    expect_true(grepl("F1 ~~ 0\\*F2", result$syntax))
})

test_that("Non-ASCII latent name is replaced with LVSEM proxy", {
    spec <- list(
        nodes = list(
            list(id = "n1", type = "latent",   label = "因孟1"),
            list(id = "n2", type = "observed", label = "x1"),
            list(id = "n3", type = "observed", label = "x2")
        ),
        edges = list(
            list(from = "n1", to = "n2", type = "loading"),
            list(from = "n1", to = "n3", type = "loading")
        )
    )
    result <- spec_to_lavaan(spec)
    expect_match(result$syntax, "^LVSEM1 =~")
    expect_equal(result$safeToLabel[["LVSEM1"]], "因孟1")
})

test_that("Empty spec returns NULL", {
    expect_null(spec_to_lavaan(list(nodes = list(), edges = list())))
    expect_null(spec_to_lavaan(list(
        nodes = list(list(id = "n1", type = "observed", label = "x1")),
        edges = list()
    )))
})

test_that("norm_syntax ignores spacing and line endings but keeps line breaks", {
    expect_equal(norm_syntax("F1  =~ x1 +  x2\r\ny1 ~ F1\n"), c("F1 =~ x1 + x2", "y1 ~ F1"))
    expect_false(identical(norm_syntax("F1 =~ x1 + x2 y1 ~ F1"), norm_syntax("F1 =~ x1 + x2\ny1 ~ F1")))
})

test_that("Covariances that are not drawn are fixed to zero: three-factor CFA", {
    result <- spec_to_lavaan(make_spec(hs_factors, hs_cfa_edges))
    expect_syntax(result$syntax, "
        visual  =~ x1 + x2 + x3
        textual =~ x4 + x5 + x6
        speed   =~ x7 + x8 + x9
        visual  ~~ 0*textual
        visual  ~~ 0*speed
        textual ~~ 0*speed
    ")
    expect_equal(result$uncorrelated, list(
        c("visual", "textual"), c("visual", "speed"), c("textual", "speed")))
    expect_length(result$uncorrelatedResiduals, 0)

    # estimated as an orthogonal model by a default sem() call
    fit <- lavaan::sem(result$syntax, data = lavaan::HolzingerSwineford1939)
    est <- lavaan::parameterEstimates(fit)
    cov <- est[est$op == "~~" & est$lhs != est$rhs, ]
    expect_equal(nrow(cov), 3)
    expect_true(all(cov$est == 0))
    expect_equal(as.numeric(lavaan::fitMeasures(fit, "df")), 27)
})

test_that("Drawing a covariance removes its zero constraint and its warning", {
    edges <- c(hs_cfa_edges, list(c("visual", "~~", "textual")))
    result <- spec_to_lavaan(make_spec(hs_factors, edges))
    lines <- norm_syntax(result$syntax)
    expect_true("visual ~~ textual" %in% lines)
    expect_false(any(grepl("visual ~~ 0\\*textual", lines)))
    expect_equal(sum(grepl("~~ 0\\*", lines)), 2)
    expect_equal(result$uncorrelated, list(c("visual", "speed"), c("textual", "speed")))

    all_drawn <- c(hs_cfa_edges, list(
        c("visual", "~~", "textual"), c("speed", "~~", "visual"), c("textual", "~~", "speed")))
    result <- spec_to_lavaan(make_spec(hs_factors, all_drawn))
    expect_false(grepl("0*", result$syntax, fixed = TRUE))
    expect_length(result$uncorrelated, 0)
})

test_that("A covariance drawn and fixed by the user is not reported as undrawn", {
    spec <- make_spec(hs_factors, c(hs_cfa_edges, list(c("visual", "~~", "textual"))))
    spec$edges[[length(spec$edges)]]$constraint <- "0"
    result <- spec_to_lavaan(spec)
    expect_equal(sum(norm_syntax(result$syntax) == "visual ~~ 0*textual"), 1)
    expect_equal(result$uncorrelated, list(c("visual", "speed"), c("textual", "speed")))
})

test_that("Residual covariances of outcomes fixed to zero are reported apart from the latent ones", {
    result <- spec_to_lavaan(make_spec(character(0), list(
        c("x1", "~>", "x4"), c("x2", "~>", "x4"),
        c("x1", "~>", "x5"), c("x2", "~>", "x5"))))
    expect_syntax(result$syntax, "
        x4 ~ x1 + x2
        x5 ~ x1 + x2
        x4 ~~ 0*x5
    ")
    expect_length(result$uncorrelated, 0)
    expect_equal(result$uncorrelatedResiduals, list(c("x4", "x5")))

    # two latent outcomes of the same factor, under their original labels
    result <- spec_to_lavaan(make_spec(c("因子1", "因子2", "因子3"), c(
        loadings_of("因子1", c("x1", "x2", "x3")),
        loadings_of("因子2", c("x4", "x5", "x6")),
        loadings_of("因子3", c("x7", "x8", "x9")),
        list(c("因子1", "~>", "因子2"), c("因子1", "~>", "因子3")))))
    expect_length(result$uncorrelated, 0)
    expect_equal(result$uncorrelatedResiduals, list(c("因子2", "因子3")))
})

test_that("Uncorrelated latent variables are reported under their original labels", {
    result <- spec_to_lavaan(make_spec(c("因子1", "因子2"), c(
        loadings_of("因子1", c("x1", "x2", "x3")),
        loadings_of("因子2", c("x4", "x5", "x6")))))
    expect_true("LVSEM1 ~~ 0*LVSEM2" %in% norm_syntax(result$syntax))
    expect_equal(result$uncorrelated, list(c("因子1", "因子2")))
})

# A covariance that lavaan adds on its own and that the generated syntax fails
# to fix would be estimated silently. So the syntax, run through a default
# sem() call, must free exactly the parameters that the drawn paths alone free
# when lavaan's automatic covariances are switched off.
test_that("Generated syntax leaves no covariance for lavaan to add", {
    models <- list(
        cfa = make_spec(hs_factors, hs_cfa_edges),
        cfa_one_cov = make_spec(hs_factors, c(hs_cfa_edges, list(c("visual", "~~", "textual")))),
        path_two_outcomes = make_spec(character(0), list(
            c("x1", "~>", "x4"), c("x2", "~>", "x4"), c("x1", "~>", "x5"), c("x1", "~>", "x6"))),
        mediation = make_spec(character(0), list(
            c("x1", "~>", "x2"), c("x2", "~>", "x3"), c("x1", "~>", "x3"))),
        higher_order = make_spec(c(hs_factors, "g"), c(hs_cfa_edges,
            loadings_of("g", hs_factors))),
        structural = make_spec(hs_factors, c(hs_cfa_edges, list(
            c("visual", "~>", "speed"), c("textual", "~>", "speed")))),
        structural_two_outcomes = make_spec(hs_factors, c(hs_cfa_edges, list(
            c("visual", "~>", "textual"), c("visual", "~>", "speed")))),
        latent_and_observed_predictors = make_spec(c("visual", "textual"), c(
            hs_cfa_edges[1:6], list(
            c("visual", "~>", "x9"), c("textual", "~>", "x9"), c("x7", "~>", "x9"), c("x8", "~>", "x9")))),
        bifactor = make_spec(c("g", "s1", "s2", "s3"), c(
            loadings_of("g",  paste0("x", 1:9)),
            loadings_of("s1", c("x1", "x2", "x3")),
            loadings_of("s2", c("x4", "x5", "x6")),
            loadings_of("s3", c("x7", "x8", "x9"))))
    )
    data <- lavaan::HolzingerSwineford1939
    for (name in names(models)) {
        syntax <- spec_to_lavaan(models[[name]])$syntax
        drawn  <- grep("~~ 0*", strsplit(syntax, "\n")[[1]], fixed = TRUE, invert = TRUE, value = TRUE)
        for (std.lv in c(TRUE, FALSE)) {
            expect_identical(
                free_params(syntax, data = data, std.lv = std.lv),
                free_params(drawn, data = data, std.lv = std.lv,
                            auto.cov.lv.x = FALSE, auto.cov.y = FALSE),
                info = paste(name, "std.lv =", std.lv)
            )
        }
    }
})

test_that("Fit of the examples with all covariances drawn is unchanged", {
    data <- lavaan::HolzingerSwineford1939
    fit_of <- function(spec) {
        fit <- lavaan::sem(spec_to_lavaan(spec)$syntax, data = data, std.lv = TRUE)
        round(as.numeric(lavaan::fitMeasures(fit, c("chisq", "df", "cfi", "rmsea"))), 3)
    }
    cfa <- make_spec(hs_factors, c(hs_cfa_edges, list(
        c("visual", "~~", "textual"), c("visual", "~~", "speed"), c("textual", "~~", "speed"))))
    higher_order <- make_spec(c(hs_factors, "g"), c(hs_cfa_edges, loadings_of("g", hs_factors)))
    expect_equal(fit_of(cfa),          c(85.306, 24, 0.931, 0.092))
    expect_equal(fit_of(higher_order), c(85.306, 24, 0.931, 0.092))
})
