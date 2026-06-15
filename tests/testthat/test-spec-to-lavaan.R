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
    expect_equal(result$syntax, "F1 =~ x1 + x2 + x3")
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
    lines <- strsplit(result$syntax, "\n")[[1]]
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
    expect_equal(result$syntax, "y1 ~ x1")
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
    lines <- strsplit(result$syntax, "\n")[[1]]
    expect_true(any(grepl("^F2 ~ F1$", lines)))
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
