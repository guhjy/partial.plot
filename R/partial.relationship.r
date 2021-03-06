#------------------------------------------------------------------------------
#	Names of models supported by lsmeans.
#------------------------------------------------------------------------------
LSMEANS_COMPATIBLE_MODELS <- c(
	"glm", glmer = "glmerMod", "glmmadmb", "lm", "lme", lmer = "lmerMod",
	"MCMCglmm"
)

LSMEANS_INCOMPATIBLE_MODELS <- c(
	cforest = "RandomForest", ctree = "BinaryTree", "gam", "gamm", "gbm",
	"glmmML", "randomForest", "ranger", "rpart", "svm", "tree"
)

#------------------------------------------------------------------------------
#	変依存性を計算するクラス。
#------------------------------------------------------------------------------
#'	(Internal) A reference class calculates partial relationship.
#'
#'	@field data
#'		data.frame to keep calculated partial relationship data.
#'
#'	@field data.split
#'		a list having splitted data.frame for each group specified in x.names.
#'
#'	@field settings
#'		class settings.
#'
#'	@include pp.settings.r
#------------------------------------------------------------------------------
partial.relationship <- setRefClass(
	"partial.relationship",
	field = list(
		data = "data.frame",
		data.split = "list",
		settings = "pp.settings"
	)
)


#------------------------------------------------------------------------------
#	クラスを初期化して偏依存性を計算する。
#------------------------------------------------------------------------------
partial.relationship$methods(
	initialize = function(settings) {
		"
		Initialize class and calculate partial.relationship data.

		\\describe{
			\\item{settings}{pp.settings object having function settings.}
		}
		"
		# Safe-guard for internal processing of reference class.
		if (missing(settings)) {
			return()
		}
		.self$settings <- settings
		# Calculate partial relationship data.
		if (!any(class(settings$model) %in% LSMEANS_INCOMPATIBLE_MODELS)) {
			.self$data <- .self$partial.relationship.lsmeans()
		} else {
			.self$data <- .self$partial.relationship.internal()
		}
		# Split data.
		if (length(settings$x.names.factor) == 0) {
			.self$data.split <- list(all = .self$data)
		} else {
			.self$data.split <- split(
				.self$data, .self$data[settings$x.names.factor],
				sep = settings$sep
			)
		}
		# Assign data to settings object.
		settings$set.relationship(.self)
	}
)


#------------------------------------------------------------------------------
#	lsmeansを使って予測値と信頼区間を計算する。
#------------------------------------------------------------------------------
partial.relationship$methods(
	partial.relationship.lsmeans = function() {
		"
		Calculate partial regression lines and intervals.

		This function calculates data for regression lines and intervals using
		\\code{\\link[emmeans]{lsmeans}} function and returns a data.frame.
		"
		# calculate prediction.
		# 予測値を計算。
		at <- c(.self$settings$numeric.sequences, .self$settings$factor.levels)
		rg <- ref_grid(
			.self$settings$model, at, data = .self$settings$data,
			type = .self$settings$type
		)
		lsm <- .self$summarize.ref.grid(rg)
		# Remove predictions with out-ranged explanatory variable for each group.
		# 各グループの説明変数の範囲を外れた予測値を削除。
		lsm <- .self$filter.result(lsm)
		return(as.data.frame(lsm))
	}
)


#------------------------------------------------------------------------------
#	mcmcを使わずにlsmeansを使って予測値と信頼区間を計算する。
#------------------------------------------------------------------------------
partial.relationship$methods(
	summarize.ref.grid.without.mcmc = function(lsm) {
		result <- summary(lsm, level = .self$settings$interval.levels)
		colnames(result) <- gsub(
			"^lsmean$|^response$|^prob$|^rate$", "fit", colnames(result)
		)
		colnames(result) <- gsub(
			"^lower.CL$|^asymp.LCL$", "lower", colnames(result)
		)
		colnames(result) <- gsub(
			"^upper.CL$|^asymp.UCL$", "upper", colnames(result)
		)
		return(result)
	}
)


#------------------------------------------------------------------------------
#	mcmcとlsmeansを使って予測値と信頼区間を計算する。
#------------------------------------------------------------------------------
partial.relationship$methods(
	summarize.ref.grid.with.mcmc = function(lsm) {
		lsm.mcmc <- as.mcmc(lsm)
		m <- apply(lsm.mcmc, 2, mean)
		interval.levels <- c(
			.self$settings$interval.levels, 1 - .self$settings$interval.levels
		)
		q <- t(apply(lsm.mcmc, 2, quantile, prob = sort(interval.levels)))
		colnames(q) <- c("lower", "upper")
		result <- suppressMessages(
			summary(lsm, level = .self$settings$interval.levels)
		)
		result <- result[.self$settings$x.names]
		result$fit <- m
		result <- cbind(result, q)
		return(result)
	}
)


#------------------------------------------------------------------------------
#	lsmeansを使って予測値と信頼区間を計算する。
#------------------------------------------------------------------------------
partial.relationship$methods(
	summarize.ref.grid = function(rg) {
		lsm <- lsmeans(rg, .self$settings$x.names)
		if (length(lsm@post.beta) == 1 & all(is.na(lsm@post.beta))) {
			return(.self$summarize.ref.grid.without.mcmc(lsm))
		}
		coda.available <- require(coda)
		if (coda.available) {
			return(.self$summarize.ref.grid.with.mcmc(lsm))
		}
		return(.self$summarize.ref.grid.without.mcmc(lsm))
	}
)


#------------------------------------------------------------------------------
#	クラスターで予測値を計算するラッパー関数。
#------------------------------------------------------------------------------
partial.relationship$methods(
	predict.stats = function(
		newdata, predict.fun, new.value.grid, index, levels, type
	) {
		"
		Calculate prediction in cluster.

		\\describe{
			\\item{\\code{newdata}}{newdata for prediction.}
			\\item{\\code{predict.fun}}{predict function.}
			\\item{\\code{new.value.grid}}{
				a data.frame having all combination of focal values of
				partial relationship grid.
			}
			\\item{\\code{index}}{
				row index of \\code{new.value.grid} where predicted values
				are calculated.
			}
			\\item{\\code{levels}}{levels of quantiles.}
		}
		"
		on.exit(gc())
		# Make data for prediction.
		# 予測用データを作成。
		replace.values <- new.value.grid[index, ]
		param.names <- names(new.value.grid)
		newdata[param.names] <- replace.values
		# Make prediction.
		prediction <- predict.fun(newdata = newdata, type = type)
		if (type == "prob") {
			prediction$fit <- prediction$fit[, .self$settings$positive.class]
		}
		quantiles <- quantile(prediction$fit, probs = levels, na.rm = TRUE)
		result <- c(fit = mean(prediction$fit), quantiles, replace.values)
		names(result) <- c("fit", "lower", "upper", param.names)
		result <- as.data.frame(as.list(result))
		return(result)
	}
)


#------------------------------------------------------------------------------
#	偏依存関係を自前で計算する関数。主に機械学習モデル用。
#------------------------------------------------------------------------------
partial.relationship$methods(
	partial.relationship.internal = function() {
		"
		Calculate partial relationship data internally.
		Mainly used for machine learning methods.
		"
		# prepare combinations of x variables.
		# 説明変数の組み合わせを用意。
		grid <- do.call(
			expand.grid,
			c(.self$settings$numeric.sequences, .self$settings$factor.levels)
		)
		grid <- .self$filter.result(grid)
		# Run calculation.
		# 計算実行
		result <- .self$calculate.relationship(grid)
		return(result)
	}
)


#------------------------------------------------------------------------------
#	予測値を計算する関数。
#	偏残差の計算にも使う必要があるので
#	partial.relationship.internalから分離して関数にした。
#------------------------------------------------------------------------------
partial.relationship$methods(
	calculate.relationship = function(grid) {
		"
		Calculate partial relationship.
		\\describe{
			\\item{\\code{grid}}{
				explanatory variables where predicted values are calculated.
			}
		}
		"
		result <- settings$cluster.apply(
			X = 1:nrow(grid), FUN = .self$predict.stats,
			newdata = .self$settings$data,
			predict.fun = .self$settings$adapter$predict,
			new.value.grid = grid, levels = .self$settings$interval.levels,
			type = ifelse(.self$settings$type == "prob", "prob", "link")
		)
		result <- do.call(rbind, result)
		if (.self$settings$type == "response") {
			for (i in c("fit", "lower", "upper")) {
				result[[i]] <- .self$settings$adapter$linkinv(result[[i]])
			}
		}
		return(result)
	}
)


#------------------------------------------------------------------------------
#	lsmeansの結果から、各グループごとにX軸の値が元のデータの範囲外に
#	ある予測値を削除する。
#------------------------------------------------------------------------------
partial.relationship$methods(
	filter.result = function(prediction) {
		"
		Remove out-ranged values from result of lsmeans.

		This internal function removes predicted values those explanatory
		variable is out of range of original data used for modeling for each
		group and returns a resultant data.frame.

		\\describe{
			\\item{prediction}{result of lsmeans.}
		}
		"
		if (
			length(.self$settings$factor.levels) == 0
			| .self$settings$extrapolate
		) {
			return(prediction)
		}
		# Get list of unique factors.
		# 因子の一覧を作成。
		factors <- expand.grid(.self$settings$factor.levels)
		# Split data and prediction for each factor group.
		# データを因子のグループごとに分割。
		sep = .self$settings$sep
		pred.split <- split(prediction, prediction[names(factors)], sep = sep)
		orig.data.split <- split(
			.self$settings$data, .self$settings$data[names(factors)], sep = sep
		)
		# Filter out out-ranged numeric values.
		# 範囲外の数値を削除。
		result <- list()
		for (i in 1:nrow(factors)) {
			split.name <- combine.columns(
				as.data.frame(factors[i, ]), sep = sep
			)
			current.pred <- pred.split[[split.name]]
			current.data <- orig.data.split[[split.name]]
			for (numeric.name in .self$settings$x.names.numeric) {
				var.range <- range(current.data[[numeric.name]])
				filter <- current.pred[[numeric.name]] >= var.range[1]
				filter <- filter & current.pred[[numeric.name]] <= var.range[2]
				current.pred <- current.pred[filter, ]
			}
			result[[split.name]] <- current.pred
		}
		result <- do.call(rbind, result)
		return(result)
	}
)
