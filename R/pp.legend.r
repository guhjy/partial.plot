#-------------------------------------------------------------------------------
#	partial.plotの結果を用いてレジェンドを描画する。
#-------------------------------------------------------------------------------
#'	Draw legend of partial plot.
#'
#'	@param object
#'		\code{\link{pp.info}} object resulted by\code{\link{partial.plot}}.
#'	@param x 
#'		position of the legend. For the detail, see 
#'		\code{\link[grahpic]{legend}} function.
#'		
#'	@param ...
#'		other graphic parameters passed to \code{\link[grahpic]{legend}} 
#'		function.
#'
#'	@export
#'
#'	@examples
#'
#'	data(iris)
#'	model <- lm(
#'		Petal.Length ~ (Sepal.Length + Petal.Width) * Species, data = iris
#'	)
#'	info <- partial.plot(model, c("Sepal.Length", "Species"), pch = 16)
#'	partial.plot.legend(info, "topleft")
#-------------------------------------------------------------------------------
pp.legend <- function(object, x, ...) {
	if (!is(object, "pp.settings")) {
		stop("'object' should be an instance of 'pp.settings' class")
	}
	# Prepare arguments for prepare.args.for.legend().
	# prepare.args.for.legend()の引数を用意。
	call <- match.call()
	call$object <- NULL
	call <- match.call(legend, call)
	call <- as.list(call)
	call[[1]] <- NULL
	# Make arguments for legend().
	# legend()の引数を作成。
	legend.args <- prepare.args.for.legend(object, as.list(call))
	legend.args <- legend.args[
		names(legend.args) %in% names(as.list(args(legend)))
	]
	do.call(legend, legend.args)
}


#-------------------------------------------------------------------------------
#	レジェンドの描画に使う引数を用意する。
#-------------------------------------------------------------------------------
#'	(Internal) Prepare arguments used for legend.
#'
#'	@param settings
#'		an object of \code{\link{pp.settings}} object having settings of
#'		partial.plot.
#'	@param legend.args
#'		a list containing arguments used for \code{\link[grahpic]{legend}}
#'		function manually specified by users.
#'
#'	@value
#'		A list containing arguments used for \code{\link[grahpic]{legend}}
#'		function
#-------------------------------------------------------------------------------
prepare.args.for.legend = function(settings, legend.args) {
	# Prepare arguments overriding arguments of legend.
	# legend関数の引数を用意。
	col <- set.group.color(settings, TRUE)
	args.to.override <- list(
		col = col, legend = names(col),
		title = paste0(get.factor.names(settings), collapse = settings$sep)
	)
	args.to.override <- c(args.to.override, settings$other.pars)
	for (i in names(args.to.override)) {
		if (is.null(legend.args[[i]])) {
			legend.args[[i]] <- args.to.override[[i]]
		}
	}
	# Set line type based on the setting of partial.plot.
	# 線の種類をpartial.plotの設定に基づいて決定。
	if (settings$draw.relationships) {
		if (is.null(legend.args$lty)) {
			legend.args$lty <- "solid"
		}
	} else {
		legend.args <- NULL
	}
	# Set plot character based on the setting of partial.plot.
	# 点のシンボルをpartial.plotの設定に基づいて決定。
	if (settings$draw.residuals) {
		if (is.null(legend.args$pch)) {
			legend.args$pch = 1
		}
	} else {
		legend.args$pch <- NULL
	}
	return(legend.args)
}
