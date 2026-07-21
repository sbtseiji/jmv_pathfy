#!/usr/bin/env Rscript
#
# Regenerates R/editor_html.R from inst/html/semgui_editor.html.
#
# inst/html/semgui_editor.html is the file to edit by hand (it gets syntax
# highlighting as real HTML/CSS/JS). It is NOT shipped inside the built .jmo,
# so R/editor_html.R — a single .EDITOR_HTML string constant — is what the
# package actually loads at runtime. Run this script after every edit to
# inst/html/semgui_editor.html to keep the two in sync.

html <- paste(readLines("inst/html/semgui_editor.html", encoding = "UTF-8"), collapse = "\n")
escaped <- gsub("\\", "\\\\", html, fixed = TRUE)
escaped <- gsub("\"", "\\\"", escaped, fixed = TRUE)

out <- c(
    "# GENERATED FILE — do not edit directly.",
    "# Source: inst/html/semgui_editor.html",
    "# Regenerate with: Rscript scripts/build_editor_html.R",
    paste0(".EDITOR_HTML <- \"", escaped, "\"")
)
writeLines(out, "R/editor_html.R", useBytes = TRUE)
cat("wrote R/editor_html.R from inst/html/semgui_editor.html\n")
