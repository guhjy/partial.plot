#------------------------------------------------------------------------------
#	partial.plotの情報を保持するクラス。
#-------------------------------------------------------------------------------
#'	(Internal) A reference class to keep settings/information of partial.plot.
#'
#'	This reference class keeps information used for partial.plot.
#'	This class is not intended to be used by users directly.
#'
#'	@field adapter
#'		an instance of model.adapter.
#'	@field model
#'		a supported model object used for plotting.
#'	@field x.names
#'		a character vector representing names of explanatory variables used 
#'		for plotting.
#'	@field data
#'		a data.frame containing data used for plotting.
#'	@field draw.residuals
#'		a logical representing that partial.plot drew residual points or not.
#'	@field draw.relationships
#'		a logical representing that partial.plot drew predicted relationships
#'		or not.
#'	@field resolution
#'		an integer specifying resolution of lines, polygons, wireframes,
#'		and images of numeric variables. 
#'	@param col
#'		a function or named character vector representing color of the graph 
#'		object.
#'		For the detail, see pal option of \code{\link{color.ramp}} function.
#'	@field xlab
#'		a character specifying used for label of X axis.
#'	@field ylab
#'		a character specifying used for label of Y axis.
#'	@field title
#'		a character representing title of the legend.
#'	@field other.pars
#		a list containing other graphic parameters passed to partial.plot().
#-------------------------------------------------------------------------------
pp.settings <- setRefClass(
	"pp.settings",
	fields = list(
		adapter = "ANY",
		model = "ANY",
		x.names = "character",
		data = "data.frame",
		draw.residuals = "logical",
		draw.relationships = "logical",
		resolution = "integer",
		col = "ANY",
		xlab = "character",
		ylab = "character",
		title = "character",
		other.pars = "list"
	)
)


pp.settings$methods(
	initialize = function(
		model, x.names, data, draw.residuals = TRUE, draw.relationships = TRUE,
		resolution = 100L, col = gg.colors, 
		xlab = character(), ylab = character(), title = "", ...
	) {
		"
		Initialize pp.settings object.
		\\describe{
			\\item{model}{a supported model object used for plotting.}
			\\item{x.names}{
				a character vector representing names of explanatory variables
				used for plotting.
			}
			\\item{data}{a data.frame containing data used for plotting.}
			\\item{draw.residuals}{
				whether the partial.plot drewn residual points or not.
			}
			\\item{draw.relationships}{
				whether partial.plot drew predicted relationships or not.
			}
			\\item{resolution}{
				an integer specifying resolution of lines, polygons,
				wireframes, and images of numeric variables.
			}
			\\item{col}{color vector.}
			\\teim{xlab, ylab}{
				a character specifying used for label of X/Y axis.
			}
			\\item{title}{legend title.}
		}
		"
		if (missing(model) | missing(x.names) | missing(data)) {
			return()
		}
		initFields(
			adapter = model.adapter(model, data = data),
			model = model, x.names = x.names,
			draw.residuals = draw.residuals, 
			draw.relationships = draw.relationships, resolution = resolution,
			col = col, title = title, other.pars = list(...)
		)
		if (!is.null(xlab)) {
			initFields(xlab = xlab)
		}
		if (!is.null(ylab)) {
			initFields(ylab = ylab)
		}
		initFields(data = adapter$data)
		.self$check.params()
	}
)



#-------------------------------------------------------------------------------
#	パラメーターの整合性を確認する。
#-------------------------------------------------------------------------------
pp.settings$methods(
	check.params = function() {
		"
		Check cerrors in specified parameters and stop if any errors are found.
		"
		# check availability of data.
		# dataが使えるかを確認。
		if (is.null(adapter$data)) {
			stop("'model' object does not have original data. Please specify 'data' argument.")
		}
		# check x.names.
		# x.namesのチェック。
		if (!all(x.names %in% colnames(adapter$data))) {
			error <- x.names[!x.names %in% colnames(adapter$data)]
			stop(sprintf("\n Column '%s' is not found in data.", error))
		}
		if (!all(x.names %in% adapter$x.names(type = "base"))) {
			error <- x.names[!x.names %in% adapter$x.names(type = "base")]
			stop(
				sprintf("\n '%s' is not found in explanatory variables.", error)
			)
		}
		# Check number of continuous explanatory variables
		# 連続値の説明変数の数チェック
		var.types <- sapply(adapter$data[, x.names, drop = FALSE], class)
		n.continuous <- sum(var.types == "numeric")
		if (n.continuous > 2) {
			stop("Plotting more than two continuous explanatory variables is not supported.")
		}
	}
)


pp.settings$methods(
	build.legend.args = function(x, ...) {
		"
		Prepare arguments for \\code{\\link[graphic]{legend}} function.
		\\describe{
			\\item{x}{x argument of \\code{\\link[graphic]{legend}} function.}
			\\item{...}{
				other arguments passed to \\code{\\link[graphic]{legend}} 
				function.
			}
		}
		"
		# Prepare arguments for legend function.
		# legend関数の引数を用意。
		legend.args <- list(x = x, ...)
		replace.args <- list(col = col, title = title, legend = names(col))
		replace.args <- c(replace.args, other.pars)
		for (i in names(replace.args)) {
			if (is.null(legend.args[[i]])) {
				legend.args[[i]] <- replace.args[[i]]
			}
		}
		# Set line type based on the setting of partial.plot.
		# 線の種類をpartial.plotの設定に基づいて決定。
		if (draw.relationships) {
			if (is.null(legend.args$lty)) {
				legend.args$lty <- "solid"
			}
		} else {
			legend.args <- NULL
		}
		# Set plot character based on the setting of partial.plot.
		# 点のシンボルをpartial.plotの設定に基づいて決定。
		if (draw.residuals) {
			if (is.null(legend.args$pch)) {
				legend.args$pch = 1
			}
		} else {
			legend.args$pch <- NULL
		}
		return(legend.args)
	}
)

