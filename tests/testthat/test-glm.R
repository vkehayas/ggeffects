if (suppressWarnings(
  require("testthat") &&
  require("ggeffects") &&
  require("lme4") &&
  require("sjlabelled") &&
  require("sjmisc")
)) {

  context("ggeffects, logistic regression")

  # glm, logistic regression ----
  data(efc)
  efc$neg_c_7d <- dicho(efc$neg_c_7)
  fit <- glm(neg_c_7d ~ c12hour + e42dep + c161sex + c172code, data = efc, family = binomial(link = "logit"))

  m <- glm(
    cbind(incidence, size - incidence) ~ period,
    family = binomial,
    data = lme4::cbpp
  )

  test_that("ggpredict, glm", {
    ggpredict(fit, "c12hour")
    ggpredict(fit, c("c12hour", "c161sex"))
    ggpredict(fit, c("c12hour", "c161sex", "c172code"))
  })

  test_that("ggaverage, glm", {
    ggaverage(fit, "c12hour")
    ggaverage(fit, c("c12hour", "c161sex"))
    ggaverage(fit, c("c12hour", "c161sex", "c172code"))
  })

  test_that("ggeffect, glm", {
    ggeffect(fit, "c12hour")
    ggeffect(fit, c("c12hour", "c161sex"))
    ggeffect(fit, c("c12hour", "c161sex", "c172code"))
  })

  test_that("ggeffects, glm", {
    ggpredict(m, "period")
    ggeffect(m, "period")
  })

  test_that("ggpredict, glm, robust", {
    ggpredict(fit, "c12hour", vcov.fun = "vcovHC", vcov.type = "HC1")
    ggpredict(fit, c("c12hour", "c161sex"), vcov.fun = "vcovHC", vcov.type = "HC1")
    ggpredict(fit, c("c12hour", "c161sex", "c172code"), vcov.fun = "vcovHC", vcov.type = "HC1")
  })

  test_that("ggeffects, glm, robust", {
    ggpredict(m, "period", vcov.fun = "vcovHC", vcov.type = "HC1")
  })
}
