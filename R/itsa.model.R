#' Run Interrupted Time Series Analyses
#'
#' Sets up an Interrupted Time Series Analysis (ITSA) for analysing short time series data.
#'
#' @param data define data
#' @param time define time variable, must either be numeric (such as a year) or of class date
#' @param depvar define dependent variable, must be continuous
#' @param interrupt_var define interruption treatment/condition variable, must be a factor
#' @param covariate_one specify a covariate control variable, default is NULL
#' @param covariate_two specify a second covariate control variable, default is NULL
#' @param alpha desired alpha (p-value boundary of null hypothesis rejection), default is 0.05.
#' @param no.plots logical, specify whether function should return the ITSA plot, default is FALSE
#' @export itsa.model
#'
#' @keywords time series, interrupted time series, analysis of variance
#'
#' @examples
#'
#' # Build variables
#'
#' year <- c(2001, 2002, 2003, 2004, 2005, 2006, 2007, 2008,
#' 2009, 2010, 2011, 2012, 2013, 2014, 2015, 2016)
#' depv <- c(8.22, 8.19, 8.23, 8.28, 8.32, 8.39, 8.02,
#' 7.92, 7.62, 7.23, 7.1, 6.95, 7.36, 7.51, 7.78, 7.92)
#' interruption <- c(0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0)
#' cov1 <- c(3.1, 3.3, 5.1, 5.2, 5.4, 4.5, 4.7, 4.9, 5.3,
#' 5.6, 5.8, 4.8, 5.2, 4.5, 4.6, 5.1)
#'
#' x <- as.data.frame(cbind(year, depv, interruption, cov1))
#'
#' # First example model
#' itsa.model(data=x, time="year", depvar="depv", interrupt_var = "interruption", alpha=0.01)
#'
#' # Add a covariate
#' itsa.model(data=x, time="year", depvar="depv", interrupt_var = "interruption",
#' covariate_one = "cov1", alpha=0.1)
#'
#' # Example no significant result
#' itsa.model(data=x, time="year", depvar="cov1", interrupt_var = "interruption", alpha=0.05)
#'
#' # Example warning
#' itsa.model(data=x, time="year", depvar="interruption", interrupt_var = "depv", alpha=0.1)
#'
#' @details This function provides a front door for the aov function in R's stats package, setting it up for running Interrupted Time Series Analysis (ITSA).
#'
#' Variable names must be defined using quotation marks.
#'
#' Returns tables of time-group means (including counts and standard deviations), results from analysis of variance, and a summary of the result. If there is suggestion of normality/homoscedasticity assumption violation in the model, a warning message will appear.
#'
#' Summary object is created in the global environment named itsa.fit which contains results and necessary information for running post-estimation itsa.postest function. It also contains the Time Series Interruption plot (itsa.plot).
#'
#' If any of data, depvar, interrupt_var, or time are undefined, the function will stop and an error message will appear


itsa.model <- function(data = NULL, time = NULL, depvar = NULL, interrupt_var = NULL,
                       covariate_one = NULL, covariate_two = NULL, alpha = 0.05, no.plots=FALSE) {

  ## Save global options and set new ones
  default_ops <- options()
  options(show.signif.stars = FALSE)


  ## Check variable specifications

  if(missing(data)){
    stop("Error: data not defined", call.=TRUE)
  }

  if(missing(depvar)){
    stop("Error: dependent variable not defined", call.=TRUE)
  }

  if(missing(interrupt_var)){
    stop("Error: independent variable not defined", call.=TRUE)
  }

  if(missing(time)){
    stop("Error: time variable not defined", call.=TRUE)
  }

  ## Assign values

  if(missing(covariate_one) & missing(covariate_two)){

    x <- data.frame(depvar=data[,depvar],
                    interrupt_var=as.factor(data[,interrupt_var]))

  }

  else{

    if(missing(covariate_two)){
      x <- data.frame(depvar=data[,depvar],
                      interrupt_var=as.factor(data[,interrupt_var]),
                      covariate_one=data[,covariate_one])

    }

    else {
      x <- data.frame(depvar=data[,depvar],
                      interrupt_var=as.factor(data[,interrupt_var]),
                      covariate_one=data[,covariate_one],
                      coveriate_two=data[,covariate_two])
    }
  }

  ## Build object for means

  ITSMeanValues <- plyr::ddply(x, ~interrupt_var,
                               plyr::summarise,count=length(depvar),
                               mean=mean(depvar, na.rm=TRUE),s.d.=stats::sd(depvar, na.rm=TRUE))

  ## Build AN(C)OVA summary objects

  model <- stats::aov(data = x, depvar ~ .)

  ITSModResult <- summary(model)

  stest <- stats::shapiro.test(model$residuals)
  stest_r <- round(stest[["p.value"]], digits=4)

  ltest <- car::leveneTest(model$residuals ~ x$interrupt_var)
  ltest_r <- round((ltest[1,3]), digits=4)

  result <- ifelse(ITSModResult[[1]][["Pr(>F)"]][[1]] < alpha,
                   "Significant variation between time periods with chosen alpha",
                   "No significant variation between time periods with chosen alpha")

  post_sums <- ifelse((stest_r < 0.05 | ltest_r < 0.05),
                      "Warning: Result may be biased by abnormality in residuals or heterogenous variances, please check post-estimation function",
                      "")

  ## Build and save plot
  if(no.plots==FALSE) {
    graphics::plot.new()
    l <- graphics::legend(graphics::par('usr')[2], graphics::par('usr')[4], bty='n', xpd=NA,
                          c("Response var", "Interruption"), col=c("black","dark grey"), lty=c(1,1), cex=0.5)
    w <- graphics::grconvertX(l$rect$w, to='ndc') - graphics::grconvertX(0, to='ndc')
    graphics::par(mar=c(5, 4, 4, 5), xpd=TRUE, omd=c(0, 1-w, 0, 1))
    graphics::plot(data[,time], x$depvar, type = "l",
                   xlab ="", ylab = "Response Variable Levels", col="black", main="Time Series Interruption Plot")
    graphics::axis(2)
    graphics::par(new = TRUE)
    graphics::plot(data[,time], x$interrupt_var, type = "l", axes=FALSE, xlab="", ylab="", col="dark grey")
    graphics::legend(graphics::par('usr')[2], graphics::par('usr')[4], bty='n', xpd=NA,
                     c("Response var", "Interruption"), col=c("black","dark grey"), lty=c(1,1), cex=0.9)
    itsa.plot <- grDevices::recordPlot()

  }

  else {
    print('No plot forced')
  }

  ## Build object for summary

  itsa.fit <<- as.list("ITSA Model Fit")
  itsa.fit$aov.result <<- ITSModResult
  itsa.fit$alpha <<- alpha
  itsa.fit$itsa.result <<- result
  itsa.fit$group.means <<- ITSMeanValues
  itsa.fit$residuals <<- model$residuals
  itsa.fit$fitted.values <<- model$fitted.values
  itsa.fit$shapiro.test <<- stest_r
  itsa.fit$levenes.test <<- ltest_r

  if(no.plots==FALSE) {

    itsa.fit$itsa.plot <<- itsa.plot

  }



  ## Return objects
  cat(paste('', '\n'))
  cat(paste('Mean Values of Dependent Variable Between Time Periods:', '\n'))
  print(ITSMeanValues)
  cat(paste('', '\n', '\n'))
  cat(paste('Analysis of Variances:', '\n'))
  print(ITSModResult)
  cat(paste('', '\n'))
  cat(paste('Result:', result, '( <',alpha,')'))
  cat(paste('', '\n'))
  cat(paste('', '\n'))
  cat(post_sums)

  ## reset global options
  options(default_ops)
  graphics::par(mar=c(5.1, 4.1, 4.1, 2.1), omd=c(0,1,0,1), xpd=FALSE)

}