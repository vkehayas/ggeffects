#' @importFrom purrr map flatten_df
#' @importFrom dplyr select group_by pull n_distinct case_when
#' @importFrom sjmisc round_num is_empty add_variables seq_row is_num_fac
#' @importFrom crayon blue italic red
#' @importFrom tidyr nest
#' @importFrom stats quantile
#' @importFrom rlang .data
#' @export
print.ggeffects <- function(x, n = 10, digits = 3, ...) {

  # do we have groups and facets?
  has_groups <- obj_has_name(x, "group") && length(unique(x$group)) > 1
  has_facets <- obj_has_name(x, "facet") && length(unique(x$facet)) > 1
  has_se <- obj_has_name(x, "std.error")

  cat("\n")

  lab <- attr(x, "title", exact = TRUE)
  if (!is.null(lab)) cat(crayon::blue(sprintf("# %s", lab)), "\n")

  lab <- attr(x, "x.title", exact = TRUE)
  if (!is.null(lab)) cat(crayon::blue(sprintf("# x = %s", lab)), "\n")

  consv <- attr(x, "constant.values")
  terms <- attr(x, "terms")

  x <- sjmisc::round_num(x, digits = digits)

  # if we have groups, show n rows per group

  .n <- 1

  if (has_groups) {
    .n <- dplyr::n_distinct(x$group, na.rm = T)
    if ((is.numeric(x$group) || sjmisc::is_num_fac(x$group)) && !is.null(terms) && length(terms) >= 2) {
      x$group <- sprintf("%s = %s", terms[2], as.character(x$group))
    }
  }

  if (has_facets) {
    .n <- .n * dplyr::n_distinct(x$facet, na.rm = T)
    if ((is.numeric(x$facet) || sjmisc::is_num_fac(x$facet)) && !is.null(terms) && length(terms) >= 2) {
      x$facet <- sprintf("%s = %s", terms[3], as.character(x$facet))
    }
  }


  # make sure that by default not too many rows are printed
  if (missing(n)) {
    n <- dplyr::case_when(
      .n >= 6 ~ 4,
      .n >= 4 & .n < 6 ~ 5,
      .n >= 2 & .n < 4 ~ 6,
      TRUE ~ 8
    )
  }

  if (!has_groups) {
    cat("\n")
    x <- dplyr::select(x, -.data$group)
    print.data.frame(x[get_sample_rows(x, n), ], ..., row.names = FALSE, quote = FALSE)
  } else if (has_groups && !has_facets) {
    xx <- x %>%
      dplyr::group_by(.data$group) %>%
      tidyr::nest()

    for (i in 1:nrow(xx)) {
      cat(crayon::red(sprintf("\n# %s\n", dplyr::pull(xx[i, 1]))))
      tmp <- purrr::flatten_df(xx[i, 2])
      print.data.frame(tmp[get_sample_rows(tmp, n), ], ..., row.names = FALSE, quote = FALSE)
    }
  } else {
    xx <- x %>%
      dplyr::group_by(.data$group, .data$facet) %>%
      tidyr::nest()

    for (i in 1:nrow(xx)) {
      cat(crayon::red(sprintf("\n# %s\n# %s\n", dplyr::pull(xx[i, 1]), dplyr::pull(xx[i, 2]))))
      tmp <- purrr::flatten_df(xx[i, 3])
      print.data.frame(tmp[get_sample_rows(tmp, n), ], ..., row.names = FALSE, quote = FALSE)
    }
  }

  cv <- purrr::map(
    consv,
    function(.x) {
      if (is.numeric(.x))
        sprintf("%.2f", .x)
      else
        as.character(.x)
    })

  if (!sjmisc::is_empty(cv)) {
    cv.names <- names(cv)
    cv.space <- max(nchar(cv.names))

    # ignore this string when determing maximum length
    poplev <- which(cv == "NA (population-level)")
    if (!sjmisc::is_empty(poplev))
      mcv <- cv[-poplev]
    else
      mcv <- cv

    cv.space2 <- max(nchar(mcv))

    cat(crayon::blue(paste0(
      "\nAdjusted for:\n",
      paste0(sprintf("* %*s = %*s", cv.space, cv.names, cv.space2, cv), collapse = "\n")
    )))

    cat("\n")
  }


  cat("\n")

  fitfun <- attr(x, "fitfun", exact = TRUE)
  if (has_se && !is.null(fitfun) && fitfun != "lm") {
    message("Standard errors are on link-scale (untransformed).")
  }
}


get_sample_rows <- function(x, n) {
  nr.of.rows <- sjmisc::seq_row(x)

  if (n < length(nr.of.rows)) {
    sample.rows <- round(c(
      min(nr.of.rows),
      stats::quantile(nr.of.rows, seq_len(n - 2) / n),
      max(nr.of.rows)
    ))
  } else {
    sample.rows <- nr.of.rows
  }

  sample.rows
}
