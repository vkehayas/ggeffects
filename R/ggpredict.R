#' @title Get marginal effects from model terms
#' @name ggpredict
#'
#' @description
#'   \code{ggpredict()} computes predicted (fitted) values for the
#'   response, at the margin of specific values from certain model terms,
#'   where additional model terms indicate the grouping structure.
#'   \code{ggeffect()} computes marginal effects by internally calling
#'   \code{\link[effects]{Effect}}. \code{ggaverage()} computes the average
#'   predicted values. The result is returned as tidy data frame.
#'
#' @param model A fitted model object, or a list of model objects. Any model
#'   that supports common methods like \code{predict()}, \code{family()}
#'   or \code{model.frame()} should work. For \code{ggeffect()}, any model
#'   that is supported by the \CRANpkg{effects}-package should work.
#' @param terms Character vector (or a formula) with the names of those terms
#'   from \code{model}, for which marginal effects should be displayed. At least
#'   one term is required to calculate effects for certain terms, maximum length is
#'   three terms, where the second and third term indicate the groups, i.e.
#'   predictions of first term are grouped by the levels of the second (and third)
#'   term. If \code{terms} is missing or \code{NULL}, marginal effects for each
#'   model term are calculated. It is also possible to define specific values for
#'   terms, at which marginal effects should be calculated (see 'Details').
#'   All remaining covariates that are not specified in \code{terms} are held
#'   constant (if \code{full.data = FALSE}, the default) or are set to the
#'   values from the observations (i.e. are kept as they happen to be;
#'   see 'Details'). See also argument \code{condition} and \code{typical}.
#' @param ci.lvl Numeric, the level of the confidence intervals. For \code{ggpredict()},
#'   use \code{ci.lvl = NA}, if confidence intervals should not be calculated
#'   (for instance, due to computation time).
#' @param type Character, only applies for mixed effects models and/or models
#'   with zero-inflation.
#'   \describe{
#'     \item{\code{"fe"}}{
#'     Predicted values are conditioned on the fixed effects or conditional
#'     model only. For instance, for models fitted with \code{zeroinfl} from
#'     \pkg{pscl}, this would return the predicted mean from the count component
#'     (without zero-inflation). For models of class \code{glmmTMB}, this type
#'     calls \code{predict(..., type = "link")}.
#'     }
#'     \item{\code{"re"}}{
#'     Predicted values are conditioned on the random effects. This only applies
#'     to mixed models, and \code{type = "re"} does not condition on the
#'     zero-inflation component of the model, nor on different group levels.
#'     \code{type = "re"} uses the reference level in the random effects groups
#'     (except for \pkg{glmmTMB} models, see below), and prediction intervals
#'     also consider the uncertainty in the variance parameters. For models
#'     from \pkg{glmmTMB}, this type calls \code{predict(..., type = "link")}.
#'     \strong{Note:} For \pkg{glmmTMB} models, the random effect variances only
#'     affect the confidence intervals of predictions, not the predicted values
#'     themselves (because this is currently not implemented in \pkg{glmmTMB}),
#'     i.e. predicted values are on population-level. To get predicted values
#'     for each level of the random effects groups, add the name of the related
#'     random effect term to the \code{terms}-argument (for more details,
#'     see \href{../doc/effectsatvalues.html}{this vignette}).
#'     }
#'     \item{\code{"fe.zi"}}{
#'     Predicted values are conditioned on the fixed effects and the zero-inflation
#'     component. For instance, for models fitted with \code{zeroinfl}
#'     from \pkg{pscl}, this would return the predicted response and for \pkg{glmmTMB},
#'     this would return the expected value \code{mu*(1-p)} \emph{without}
#'     conditioning on random effects. For models of class \code{glmmTMB}, this type
#'     calls \code{predict(..., type = "response")}.
#'     }
#'     \item{\code{"re.zi"}}{
#'     Predicted values are conditioned on the random effects and the
#'     zero-inflation component. For models fitted with \pkg{glmmTMB}, this
#'     would return the expected value \code{mu*(1-p)}, conditioned on random
#'     effects. Prediction intervals also consider the uncertainty in the
#'     variance parameters. For models from \pkg{glmmTMB}, this type
#'     calls \code{simulate()}, because conditioning on random effects is
#'     not yet implemented in \code{predict.glmmTMB()}.
#'     }
#'     \item{\code{"surv"} and \code{"cumhaz"}}{
#'     Applies only to \code{coxph}-objects from the \pkg{survial}-package and
#'     calculates the survival probability or the cumulative hazard of an event.
#'     }
#'     \item{\code{"debug"}}{
#'     Only used internally.
#'     }
#'   }
#' @param full.data Logical, if \code{TRUE}, the returned data frame contains
#'   predictions for all observations. This data frame also has columns
#'   for residuals and observed values, and can also be used to plot a
#'   scatter plot of all data points or fitted values.
#'   If \code{FALSE} (the default), the returned data frame only contains
#'   predictions for all combinations of unique values of the model's
#'   predictors. Residuals and observed values are set to \code{NA}.
#'   Usually, this argument is only used internally by \code{ggaverage()}.
#' @param typical Character vector, naming the function to be applied to the
#'   covariates over which the effect is "averaged". The default is "mean".
#'   See \code{\link[sjstats]{typical_value}} for options.
#' @param ppd Logical, if \code{TRUE}, predictions for Stan-models are
#'   based on the posterior predictive distribution
#'   (\code{\link[rstantools]{posterior_predict}}). If \code{FALSE} (the
#'   default), predictions are based on posterior draws of the linear
#'   predictor (\code{\link[rstantools]{posterior_linpred}}).
#' @param x.as.factor Logical, if \code{TRUE}, preserves factor-class as
#'   \code{x}-column in the returned data frame. By default, the \code{x}-column
#'   is always numeric.
#' @param condition Named character vector, which indicates covariates that
#'   should be held constant at specific values. Unlike \code{typical}, which
#'   applies a function to the covariates to determine the value that is used
#'   to hold these covariates constant, \code{condition} can be used to define
#'   exact values, for instance \code{condition = c(covariate1 = 20, covariate2 = 5)}.
#'   See 'Examples'.
#' @param vcov.fun String, indicating the name of the \code{vcov*()}-function
#'    from the \pkg{sandwich}-package, e.g. \code{vcov.fun = "vcovCL"},
#'    which is used to compute robust standard errors for predictions.
#'    If \code{NULL}, standard errors (and confidence intervals) for predictions
#'    are based on the standard errors as returned by the \code{predict()}-function.
#'    \strong{Note} that probably not all model objects that work with \code{ggpredict()}
#'    are also supported by the \pkg{sandwich}-package.
#' @param vcov.type Character vector, specifying the estimation type for the
#'    robust covariance matrix estimation (see \code{\link[sandwich]{vcovHC}}
#'    for details).
#' @param vcov.args List of named vectors, used as additional arguments that
#'    are passed down to \code{vcov.fun}.
#' @param ... For \code{ggpredict()}, further arguments passed down to
#'    \code{predict()}, and for \code{ggeffect()}, further arguments passed
#'    down to \code{\link[effects]{Effect}}. If \code{model} is of class
#'    \code{glmmTMB}, \code{...} may also be used to set the number of
#'    simulation for bootstrapped confidence intervals, e.g. \code{nsim = 500}.
#'
#' @details
#'   \strong{Supported Models}
#'   \cr \cr
#'   Currently supported model-objects are: \code{lm}, \code{glm}, \code{glm.nb},
#'   \code{lme}, \code{lmer}, \code{glmer}, \code{glmer.nb}, \code{nlmer},
#'   \code{glmmTMB}, \code{gam}, \code{vgam}, \code{gamm}, \code{gamm4},
#'   \code{multinom}, \code{betareg}, \code{gls}, \code{gee}, \code{plm},
#'   \code{lrm}, \code{polr}, \code{clm}, \code{clm2}, \code{hurdle}, \code{zeroinfl},
#'   \code{svyglm}, \code{svyglm.nb}, \code{truncreg}, \code{coxph},
#'   \code{stanreg}, \code{brmsfit}, \code{lmRob}, \code{glmRob}, \code{brglm}
#'   and \code{rlm}.
#'   Other models not listed here are passed to a generic predict-function
#'   and might work as well, or maybe with \code{ggeffect()}, which
#'   effectively does the same as \code{ggpredict()}. The main difference
#'   is that \code{ggpredict()} calls \code{predict()}, while \code{ggeffect()}
#'   calls \code{\link[effects]{Effect}} to compute marginal effects.
#'   \cr \cr
#'   \strong{Difference between \code{ggpredict()} and \code{ggeffect()}}
#'   \cr \cr
#'   \code{ggpredict()} and \code{ggeffect()} differ in how factors are
#'   held constant: \code{ggpredict()} uses the reference level, while
#'   \code{ggeffect()} computes a kind of "average" value, which represents
#'   the proportions of each factor's category.
#'   \cr \cr
#'   \strong{Marginal Effects at Specific Values}
#'   \cr \cr
#'   Specific values of model terms can be specified via the \code{terms}-argument.
#'   Indicating levels in square brackets allows for selecting only
#'   specific groups or values resp. value ranges. Term name and levels in
#'   brackets must be separated by a whitespace character, e.g.
#'   \code{terms = c("age", "education [1,3]")}. Numeric ranges, separated
#'   with colon, are also allowed: \code{terms = c("education", "age [30:60]")}.
#'   \cr \cr
#'   The \code{terms}-argument also supports the same shortcuts as the
#'   \code{values}-argument in \code{rprs_values()}. So
#'   \code{terms = "age [meansd]"} would return predictions for the values
#'   one standard deviation below the mean age, the mean age and
#'   one SD above the mean age. \code{terms = "age [quart2]"} would calculate
#'   predictions at the value of the lower, median and upper quartile of age.
#'   \cr \cr
#'   Furthermore, it is possible to specify a function name. Values for
#'   predictions will then be transformed, e.g. \code{terms = "income [exp]"}.
#'   This is useful when model predictors were transformed for fitting the
#'   model and should be back-transformed to the original scale for predictions.
#'   \cr \cr
#'   You can take a random sample of any size with \code{sample=n}, e.g
#'   \code{terms = "income [sample=8]"}, which will sample eight values from
#'   all possible values of the variable \code{income}. This option is especially
#'   useful for plotting marginal effects at certain levels of random effects
#'   group levels, where the group factor has many levels that can be completely
#'   plotted. For more details, see \href{../doc/effectsatvalues.html}{this vignette}.
#'   \cr \cr
#'   Finally, numeric vectors for which no specific values are given, a
#'   "pretty range" is calculated (see \code{\link{pretty_range}}), to avoid
#'   memory allocation problems for vectors with many unique values. If a numeric
#'   vector is specified as second or third term (i.e. if this vector represents
#'   a grouping structure), representative values (see \code{\link{rprs_values}})
#'   are chosen. If all values for a numeric vector should be used to compute
#'   predictions, you may use e.g. \code{terms = "age [all]"}. See also
#'   package vignettes.
#'   \cr \cr
#'   To create a pretty range that should be smaller or larger than the default
#'   range (i.e. if no specific values would be given), use the \code{n}-tag,
#'   e.g. \code{terms="age [n=5]"} or \code{terms="age [n=12]"}. Larger
#'   values for \code{n} return a larger range of predicted values.
#'   \cr \cr
#'   \strong{Holding covariates at constant values}
#'   \cr \cr
#'   For \code{ggpredict()}, if \code{full.data = FALSE}, \code{expand.grid()}
#'   is called on all unique combinations of \code{model.frame(model)[, terms]}
#'   and used as \code{newdata}-argument for \code{predict()}. In this case,
#'   all remaining covariates that are not specified in \code{terms} are
#'   held constant: Numeric values are set to the mean (unless changed with
#'   the \code{condition} or \code{typical}-argument), factors are set to their
#'   reference level (may also be changed with \code{condition}) and character
#'   vectors to their mode (most common element).
#'   \cr \cr
#'   \code{ggaverage()} computes the average predicted values, by calling
#'   \code{ggpredict()} with \code{full.data = TRUE}, where argument
#'   \code{newdata = model.frame(model)} is used in \code{predict()}.
#'   Hence, predictions are made on the model data. In this case, all
#'   remaining covariates that are not specified in \code{terms} are
#'   \emph{not} held constant, but vary between observations (and are
#'   kept as they happen to be). The predicted values are then averaged
#'   for each group (if any). Thus, \code{ggpredict()} can be considered
#'   as calculating marginal effects at the mean, while \code{ggaverage()}
#'   computes average marginal effects.
#'   \cr \cr
#'   \code{ggeffect()}, by default, sets remaining numeric covariates to
#'   their mean value, while for factors, a kind of "average" value, which
#'   represents the proportions of each factor's category, is used.
#'   \cr \cr
#'   \strong{Bayesian Regression Models}
#'   \cr \cr
#'   \code{ggpredict()} also works with \strong{Stan}-models from
#'   the \CRANpkg{rstanarm} or \CRANpkg{brms}-package. The predicted
#'   values are the median value of all drawn posterior samples. The
#'   confidence intervals for Stan-models are actually high density
#'   intervals, computed by \code{\link[sjstats]{hdi}}, unless \code{ppd = TRUE}.
#'   If \code{ppd = TRUE}, predictions are based on draws of the posterior
#'   predictive  distribution and the uncertainty interval is computed
#'   using  \code{\link[rstantools]{predictive_interval}}. By default (i.e.
#'   \code{ppd = FALSE}), the predictions are based on
#'   \code{\link[rstantools]{posterior_linpred}} and hence have some
#'   limitations: the uncertainty of the error term is not taken into
#'   account. The recommendation is to use the posterior predictive
#'   distribution (\code{\link[rstantools]{posterior_predict}}).
#'   Note that for binomial models, the \code{newdata}-argument
#'   used in \code{posterior_predict()} must also contain the vector
#'   with the number of trials. In this case, a dummy-vector is used,
#'   where all values for the response are set to 1.
#'   \cr \cr
#'   \strong{Zero-Inflated Mixed Models with glmmTMB}
#'   \cr \cr
#'   If \code{model} is of class \code{glmmTMB}, bootstrapped confidence
#'   intervals are calculated for predictions conditioned on the zero-inflated
#'   part of the model, when the uncertainty in the random-effect paramters
#'   is ignored (i.e. when \code{type = "fe.zi"}, see Brooks et al. 2017, pp.391-392
#'   for details). \code{type = "fe.zi"} returns predicted values at population
#'   \emph{mode}, not mean. If predictions are also conditioned on random
#'   effects (i.e. \code{type = "re.zi"}), predicted values are based on
#'   simulations (see Brooks et al. 2017, pp.392-393 for details).
#'
#' @references Brooks ME, Kristensen K, Benthem KJ van, Magnusson A, Berg CW, Nielsen A, et al. glmmTMB Balances Speed and Flexibility Among Packages for Zero-inflated Generalized Linear Mixed Modeling. The R Journal. 2017;9: 378–400.
#'
#' @note
#'   Since data for \code{ggaverage()} comes from the model frame, not all
#'   possible combinations of values in \code{terms} might be present in the data,
#'   thus lines or confidence bands from \code{plot()} might not span over
#'   the complete x-axis-range.
#'   \cr \cr
#'   \code{polr}-, \code{clm}-models, or more generally speaking, models with
#'   ordinal or multinominal outcomes, have an additional column
#'   \code{response.level}, which indicates with which level of the response
#'   variable the predicted values are associated.
#'   \cr \cr
#'   The \code{print()}-method gives a clean output (especially for predictions
#'   by groups), and indicates at which values covariates were held constant.
#'   Furthermore, the \code{print()}-method has the arguments \code{digits} and
#'   \code{n} to control number of decimals and lines to be printed.
#'
#' @return A data frame (with \code{ggeffects} class attribute) with consistent data columns:
#'         \describe{
#'           \item{\code{x}}{the values of the first term in \code{terms}, used as x-position in plots.}
#'           \item{\code{predicted}}{the predicted values of the response, used as y-position in plots.}
#'           \item{\code{std.error}}{the standard error of the predictions.}
#'           \item{\code{conf.low}}{the lower bound of the confidence interval for the predicted values.}
#'           \item{\code{conf.high}}{the upper bound of the confidence interval for the predicted values.}
#'           \item{\code{observed}}{if \code{full.data = TRUE}, this columns contains the observed values (the response vector).}
#'           \item{\code{residuals}}{if \code{full.data = TRUE}, this columns contains residuals.}
#'           \item{\code{group}}{the grouping level from the second term in \code{terms}, used as grouping-aesthetics in plots.}
#'           \item{\code{facet}}{the grouping level from the third term in \code{terms}, used to indicate facets in plots.}
#'         }
#'         For proportional odds logistic regression (see \code{\link[MASS]{polr}})
#'         resp. cumulative link models (e.g., see \code{\link[ordinal]{clm}}),
#'         an additional column \code{response.level} is returned, which indicates
#'         the grouping of predictions based on the level of the model's response.
#'
#' @examples
#' data(efc)
#' fit <- lm(barthtot ~ c12hour + neg_c_7 + c161sex + c172code, data = efc)
#'
#' ggpredict(fit, terms = "c12hour")
#' ggpredict(fit, terms = "c12hour", full.data = TRUE)
#' ggpredict(fit, terms = c("c12hour", "c172code"))
#' ggpredict(fit, terms = c("c12hour", "c172code", "c161sex"))
#'
#' # specified as formula
#' ggpredict(fit, terms = ~ c12hour + c172code + c161sex)
#'
#' # only range of 40 to 60 for variable 'c12hour'
#' ggpredict(fit, terms = "c12hour [40:60]")
#'
#' # using "summary()" shows that covariate "neg_c_7" is held
#' # constant at a value of 11.84 (its mean value). To use a
#' # different value, use "condition"
#' ggpredict(fit, terms = "c12hour [40:60]", condition = c(neg_c_7 = 20))
#'
#' # to plot ggeffects-objects, you can use the 'plot()'-function.
#' # the following examples show how to build your ggplot by hand.
#'
#' # plot predicted values, remaining covariates held constant
#' library(ggplot2)
#' mydf <- ggpredict(fit, terms = "c12hour")
#' ggplot(mydf, aes(x, predicted)) +
#'   geom_line() +
#'   geom_ribbon(aes(ymin = conf.low, ymax = conf.high), alpha = .1)
#'
#' # with "full.data = TRUE", remaining covariates vary between
#' # observations, so fitted values can be plotted
#' mydf <- ggpredict(fit, terms = "c12hour", full.data = TRUE)
#' ggplot(mydf, aes(x, predicted)) + geom_point()
#'
#' # you can add a smoothing-geom to show the linear trend of fitted values
#' ggplot(mydf, aes(x, predicted)) +
#'   geom_smooth(method = "lm", se = FALSE) +
#'   geom_point()
#'
#' # three variables, so we can use facets and groups
#' mydf <- ggpredict(
#'   fit,
#'   terms = c("c12hour", "c161sex", "c172code"),
#'   full.data = TRUE
#' )
#' ggplot(mydf, aes(x = x, y = predicted, colour = group)) +
#'   stat_smooth(method = "lm", se = FALSE) +
#'   facet_wrap(~facet, ncol = 2)
#'
#' # average marginal effects
#' mydf <- ggaverage(fit, terms = c("c12hour", "c172code"))
#' ggplot(mydf, aes(x = x, y = predicted, colour = group)) +
#'   stat_smooth(method = "lm", se = FALSE)
#'
#' # select specific levels for grouping terms
#' mydf <- ggpredict(fit, terms = c("c12hour", "c172code [1,3]", "c161sex"))
#' ggplot(mydf, aes(x = x, y = predicted, colour = group)) +
#'   stat_smooth(method = "lm", se = FALSE) +
#'   facet_wrap(~facet) +
#'   labs(
#'     y = get_y_title(mydf),
#'     x = get_x_title(mydf),
#'     colour = get_legend_title(mydf)
#'   )
#'
#' # level indication also works for factors with non-numeric levels
#' # and in combination with numeric levels for other variables
#' library(sjlabelled)
#' data(efc)
#' efc$c172code <- as_label(efc$c172code)
#' fit <- lm(barthtot ~ c12hour + neg_c_7 + c161sex + c172code, data = efc)
#' ggpredict(fit, terms = c("c12hour",
#'   "c172code [low level of education, high level of education]",
#'   "c161sex [1]"))
#'
#' # use categorical value on x-axis, use axis-labels, add error bars
#' dat <- ggpredict(fit, terms = c("c172code", "c161sex"))
#' ggplot(dat, aes(x, predicted, colour = group)) +
#'   geom_point(position = position_dodge(.1)) +
#'   geom_errorbar(
#'     aes(ymin = conf.low, ymax = conf.high),
#'     position = position_dodge(.1)
#'   ) +
#'   scale_x_continuous(breaks = 1:3, labels = get_x_labels(dat))
#'
#' # 3-way-interaction with 2 continuous variables
#' data(efc)
#' # make categorical
#' efc$c161sex <- as_factor(efc$c161sex)
#' fit <- lm(neg_c_7 ~ c12hour * barthtot * c161sex, data = efc)
#' # select only levels 30, 50 and 70 from continuous variable Barthel-Index
#' dat <- ggpredict(fit, terms = c("c12hour", "barthtot [30,50,70]", "c161sex"))
#' ggplot(dat, aes(x = x, y = predicted, colour = group)) +
#'   stat_smooth(method = "lm", se = FALSE, fullrange = TRUE) +
#'   facet_wrap(~facet) +
#'   labs(
#'     colour = get_legend_title(dat),
#'     x = get_x_title(dat),
#'     y = get_y_title(dat),
#'     title = get_title(dat)
#'   )
#'
#' # or with ggeffects' plot-method
#' \dontrun{
#' plot(dat, ci = FALSE)}
#'
#' # use factor levels as x-column in returned data frame
#' data(efc)
#' efc$c161sex <- as_label(efc$c161sex)
#' fit <- lm(neg_c_7 ~ c12hour + c161sex, data = efc)
#' ggpredict(fit, terms = "c161sex", x.as.factor = TRUE)
#'
#' # marginal effects for polynomial terms
#' data(efc)
#' fit <- glm(
#'   tot_sc_e ~ c12hour + e42dep + e17age + I(e17age^2) + I(e17age^3),
#'   data = efc,
#'   family = poisson()
#' )
#' ggeffect(fit, terms = "e17age")
#'
#' @importFrom stats predict predict.glm na.omit
#' @importFrom dplyr select mutate case_when arrange n_distinct
#' @importFrom sjmisc to_factor is_num_fac remove_empty_cols
#' @importFrom purrr map
#' @importFrom sjlabelled as_numeric
#' @importFrom sjstats resp_var re_grp_var
#' @export
ggpredict <- function(model,
                      terms,
                      ci.lvl = .95,
                      type = c("fe", "re", "fe.zi", "re.zi", "surv", "cumhaz", "debug"),
                      typical = "mean",
                      condition = NULL,
                      ppd = FALSE,
                      x.as.factor = FALSE,
                      full.data = FALSE,
                      vcov.fun = NULL,
                      vcov.type = NULL,
                      vcov.args = NULL,
                      ...) {
  # check arguments
  type <- match.arg(type)

  # check if terms are a formula
  if (!missing(terms) && !is.null(terms) && inherits(terms, "formula")) {
    terms <- all.vars(terms)
  }

  # for gamm4 objects, we have a list with two items, mer and gam
  # extract just the mer-part then
  if (inherits(model, "list") && all(names(model %in% c("mer", "gam")))) {
    model <- model$mer
    class(model) <- "lmerMod"
  }

  if (inherits(model, "list")) {
    res <- purrr::map(model, ~ggpredict_helper(
      model = .x,
      terms = terms,
      ci.lvl = ci.lvl,
      type = type,
      full.data = full.data,
      typical = typical,
      ppd = ppd,
      x.as.factor = x.as.factor,
      condition = condition,
      vcov.fun = vcov.fun,
      vcov.type = vcov.type,
      vcov.args = vcov.args,
      ...
    ))
    class(res) <- c("ggalleffects", class(res))
  } else {
    if (missing(terms) || is.null(terms)) {
      predictors <- sjstats::pred_vars(model)
      res <- purrr::map(
        predictors,
        function(.x) {
          tmp <- ggpredict_helper(
            model = model,
            terms = .x,
            ci.lvl = ci.lvl,
            type = type,
            full.data = full.data,
            typical = typical,
            ppd = ppd,
            x.as.factor = x.as.factor,
            condition = condition,
            vcov.fun = vcov.fun,
            vcov.type = vcov.type,
            vcov.args = vcov.args,
            ...
          )

          tmp$group <- .x
          tmp
        }
      )
      names(res) <- predictors
      class(res) <- c("ggalleffects", class(res))
    } else {
      res <- ggpredict_helper(
        model = model,
        terms = terms,
        ci.lvl = ci.lvl,
        type = type,
        full.data = full.data,
        typical = typical,
        ppd = ppd,
        x.as.factor = x.as.factor,
        condition = condition,
        vcov.fun = vcov.fun,
        vcov.type = vcov.type,
        vcov.args = vcov.args,
        ...
      )
    }
  }

  res
}


# workhorse that computes the predictions
# and creates the tidy data frames
#' @importFrom sjstats model_frame
ggpredict_helper <- function(model,
                             terms,
                             ci.lvl,
                             type,
                             full.data,
                             typical,
                             ppd,
                             x.as.factor,
                             condition,
                             vcov.fun,
                             vcov.type,
                             vcov.args,
                             ...) {
  # check class of fitted model
  fun <- get_predict_function(model)

  # check terms argument
  terms <- check_vars(terms)
  cleaned.terms <- get_clear_vars(terms)

  # check if predictions should be made for each group level in
  # random effects models
  if (fun %in% c("lmer", "glmer", "glmmTMB", "nlmer")) {
    re.terms <- sjstats::re_grp_var(model)
    if (!is.null(re.terms) && any(cleaned.terms %in% re.terms)) ci.lvl <- NA
  }

  # check model family, do we have count model?
  faminfo <- sjstats::model_family(model)

  if (fun == "coxph" && type == "surv") faminfo$is_bin <- TRUE

  # create logical for family
  binom_fam <- faminfo$is_bin
  poisson_fam <- faminfo$is_pois

  # get model frame
  fitfram <- sjstats::model_frame(model, fe.only = FALSE)

  # expand model frame to grid of unique combinations, if
  # user not requested full data
  if (full.data) {
    expanded_frame <- get_sliced_data(fitfram, terms)
  } else {
    expanded_frame <- get_expanded_data(
      model = model, mf = fitfram, terms = terms, typ.fun = typical,
      condition = condition
    )
  }

  # save original frame, for labels, and original terms
  ori.mf <- fitfram
  ori.terms <- terms

  # clear argument from brackets
  terms <- cleaned.terms


  # compute predictions here -----
  fitfram <- select_prediction_method(
    fun,
    model,
    expanded_frame,
    ci.lvl,
    type,
    faminfo,
    ppd,
    terms = ori.terms,
    typical,
    vcov.fun,
    vcov.type,
    vcov.args,
    ...
  )


  # init legend labels
  legend.labels <- NULL

  # for survival probabilities or cumulative hazards, we need
  # the "time" variable

  if (fun == "coxph" && type %in% c("surv", "cumhaz"))
    terms <- c("time", terms)

  # get axis titles and labels
  all.labels <- get_all_labels(
    fitfram = ori.mf,
    terms = terms,
    fun = get_model_function(model),
    binom_fam = binom_fam,
    poisson_fam = poisson_fam,
    no.transform = FALSE,
    type = type
  )

  # check for correct terms specification
  if (!all(terms %in% colnames(fitfram))) {
    stop("At least one term specified in `terms` is no valid model term.", call. = FALSE)
  }

  # now select only relevant variables: the predictors on the x-axis,
  # the predictions and the originial response vector (needed for scatter plot)

  cols.to.keep <- na.omit(match(
    c(terms, "predicted", "conf.low", "conf.high", "response.level"),
    colnames(fitfram)
  ))

  mydf <- dplyr::select(fitfram, !! cols.to.keep)


  # no full data for certain models
  if (full.data && faminfo$is_ordinal) {
    message("Argument `full.data` is not supported for ordinal or cumulative link regression model.")
    full.data <- FALSE
  }


  # for full data, we can also get observed and residuals
  if (full.data) {
    mydf <- dplyr::mutate(mydf,
      observed = sjlabelled::as_numeric(fitfram[[1]], start.at = 0, keep.labels = F),
      residuals = .data$observed - .data$predicted
    )
  } else {
    mydf <- dplyr::mutate(mydf, observed = NA, residuals = NA)
  }


  # with or w/o grouping factor?
  if (length(terms) == 1) {
    colnames(mydf)[1] <- "x"
    # convert to factor for proper legend
    mydf$group <- sjmisc::to_factor(1)
  } else {
    # name data depending on whether we have a facet-variable or not
    if (length(terms) == 2) {
      # for some models, like MASS::polr, we have an additional
      # column for the response category. So maximun ncol is 8, not 7
      max_value <- ifelse(fun %in% c("polr", "clm", "clm2", "multinom"), 8, 7)
      colnames(mydf)[1:2] <- c("x", "group")
      # reorder columns
      mydf <- mydf[, c(1, 3:max_value, 2)]
    } else {
      # for some models, like MASS::polr, we have an additional
      # column for the response category. So maximun ncol is 8, not 7
      max_value <- ifelse(fun %in% c("polr", "clm", "clm2", "multinom"), 9, 8)
      colnames(mydf)[1:3] <- c("x", "group", "facet")
      # reorder columns
      mydf <- mydf[, c(1, 4:max_value, 2:3)]
    }

    # if we have no full data, grouping variable may not be labelled
    # do this here, so we convert to labelled factor later
    if (!full.data) mydf <- add_groupvar_labels(mydf, ori.mf, terms)

    # convert to factor for proper legend
    mydf <- groupvar_to_label(mydf)

    # check if we have legend labels
    legend.labels <- sjlabelled::get_labels(mydf$group)
  }

  # if we had numeric variable w/o labels, these still might be numeric
  # make sure we have factors here for our grouping and facet variables
  if (is.numeric(mydf$group))
    mydf$group <- sjmisc::to_factor(mydf$group)

  if (obj_has_name(mydf, "facet") && is.numeric(mydf$facet))
    mydf$facet <- sjmisc::to_factor(mydf$facet)


  # remember if x is factor and if we had full data
  x.is.factor <- ifelse(is.factor(mydf$x), "1", "0")
  has.full.data <- ifelse(full.data, "1", "0")

  # x needs to be numeric
  if (!x.as.factor) mydf$x <- sjlabelled::as_numeric(mydf$x)


  # add standard errors
  se <- attr(fitfram, "std.error", exact = TRUE)

  if (is.null(se))
    se <- NA

  mydf <- sjmisc::add_variables(mydf, std.error = se, .after = "predicted")


  # sort values
  mydf <- mydf %>%
    dplyr::arrange(.data$x, .data$group) %>%
    sjmisc::remove_empty_cols()


  # check if outcome is log-transformed, and if so,
  # back-transform predicted values to response scale

  rv <- sjstats::resp_var(model)
  if (grepl("log\\((.*)\\)", rv)) {
    mydf$predicted <- exp(mydf$predicted)
    mydf$conf.low <- exp(mydf$conf.low)
    mydf$conf.high <- exp(mydf$conf.high)
    message("Model has log-transformed response. Back-transforming predictions to original response scale.")
  }


  # add raw data as well
  attr(mydf, "rawdata") <- get_raw_data(model, ori.mf, terms)


  # set attributes with necessary information
  set_attributes_and_class(
    data = mydf,
    model = model,
    t.title = all.labels$t.title,
    x.title = all.labels$x.title,
    y.title = all.labels$y.title,
    l.title = all.labels$l.title,
    legend.labels = legend.labels,
    x.axis.labels = all.labels$axis.labels,
    faminfo = faminfo,
    x.is.factor = x.is.factor,
    full.data = has.full.data,
    constant.values = attr(expanded_frame, "constant.values", exact = TRUE),
    terms = cleaned.terms
  )
}
