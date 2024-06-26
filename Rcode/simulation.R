# Import functions in "basic_functions.R"
source("basic_functions.R")

######################
#### Generate Data
######################

# Generate covariate vectors
generateX <- function(n){
  x1 <- rbinom(n, size = 1, prob = 0.5)
  x2 <- rbinom(n, size = 1, prob = 0.3)
  x3 <- round(runif(n, min = -1, max = 1), digits = 2)
  x4 <- round(runif(n, min = -2, max = 2), digits = 2)
  return (data.frame(x1, x2, x3, x4))
}

# Generate treatment & potential outcome data
generateData <- function(n, x, gamma_t = 0, eta = c(0,0), i){
  eta0 <- eta[1];  eta1 <- eta[2];
  x1 <- x[,1];x2 <- x[,2];x3 <- x[,3];x4 <- x[,4];
  if (is.element(i,c(1,2,9,10))){
    trt <- rbinom(n, size = 1, prob = plogis(-1 + 0.2*x1 + 0.2*x2 - 0.4*x3 + 0.4*x4))
    y1 <- rbinom(n, size = 1, prob= plogis(gamma_t - 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3 + 0.2*x4))
    y0 <- rbinom(n, size = 1, prob= plogis(- 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3 + 0.2*x4))
  }else if (is.element(i,c(3,4,11,12))){
    trt <- rbinom(n, size = 1, prob = plogis(-1 + 0.2*x1 + 0.2*x2 - 0.4*x3 + 0.4*x4))
    y1 <- rbinom(n, size = 1, prob= plogis(gamma_t - 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3*x3 + 0.2*x4*x4))
    y0 <- rbinom(n, size = 1, prob= plogis(- 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3*x3 + 0.2*x4*x4))
  }else if (is.element(i,c(5,6,13,14))){
    trt <- rbinom(n, size = 1, prob = plogis(-1 + 0.2*x1 + 0.2*x2 - 0.4*x3*x3 + 0.4*x4*x4))
    y1 <- rbinom(n, size = 1, prob= plogis(gamma_t - 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3 + 0.2*x4))
    y0 <- rbinom(n, size = 1, prob= plogis(- 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3 + 0.2*x4))
  }else {
    trt <- rbinom(n, size = 1, prob = plogis(-1 + 0.2*x1 + 0.2*x2 - 0.4*x3*x3 + 0.4*x4*x4))
    y1 <- rbinom(n, size = 1, prob= plogis(gamma_t - 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3*x3 + 0.2*x4*x4))
    y0 <- rbinom(n, size = 1, prob= plogis(- 0.4 + 0.2*x1 + 0.2*x2 - 0.4*x3*x3 + 0.2*x4*x4))
  }
  rb1 <- rbinom(n, size = 1, prob = eta1)
  rb0 <- rbinom(n, size = 1, prob = eta0)
  y <- as.integer(y1*trt + y0*(1-trt))
  trt_s <- as.integer(trt*(1-y*rb1-(1-y)*rb0))
  return (data.frame(x1,x2,x3,x4,trt,trt_s,y,y1,y0))
}

######################
#### Simulation Studies
######################
repn = 1000
result.mat = matrix(NA, nrow = 16, ncol = 14)

## Set the number of strata
strata = 20

## Set the block size
bsize = 50

## Simulation
for (i in 1:16){
  ## Set the recall bias parameters
  if(i<=8){eta = c(0.1, 0.1)} else {eta = c(0.1, 0.2)}
  eta0 = eta[1] 
  eta1 = eta[2]
  
  ## Set the sample size
  if(i%%2==1){n = 1000} else {n = 2000}
  
  check = rep(NA, repn)
  IPW.estimator = rep(NA, repn)
  OR.estimator = rep(NA, repn)
  ML.estimator = rep(NA, repn)
  Strat.prop.estimator = rep(NA, repn)
  Strat.prog.estimator = rep(NA, repn)
  Block.estimator = rep(NA, repn)
  Double.estimator = rep(NA, repn)
  
  X = generateX(n)
  for (j in 1:repn){
    data = generateData(n, X, gamma_t = 0.4, eta, i)
    check[j]=mean(data$y1)-mean(data$y0)
    newdata = data[, c("y", "trt_s", "x1", "x2", "x3", "x4")]
    
    # 1. ML estimator
    ML.est = ML.logistic.under(data = newdata, eta)
    ML.estimator[j] = ML.est$risk.diff
    
    # 2. Stratification with prop.star
    prop.score.model = glm(trt_s ~ x1 + x2 + x3 + x4, data = newdata, family = "binomial", x = TRUE)
    prop.score.star = prop.score.model$fitted.values
    count.mat = SP.set(newdata, strata + 1, prop.score.star)
    Strat.prop.estimator[j] = SP.inference.under(count.mat = count.mat, eta)$risk.diff
    
    # 3. Stratification with prog.star
    newdata_ts = newdata[newdata$trt_s==1,]
    prog.score.model = glm(y ~ trt_s + x1 + x2 + x3 + x4, data = newdata_ts, family = "binomial", x = TRUE)
    gamma_x = prog.score.model$coefficients[-c(1,2)]
    prog.score.star = as.matrix(newdata[,-c(1,2)]) %*% as.vector(gamma_x)
    count.mat = SP.set(newdata, strata + 1, prog.score.star)
    Strat.prog.estimator[j]=SP.inference.under(count.mat = count.mat, eta)$risk.diff
    
    # 2,3*. Double Score Stratification
    count.mat = DSP.set(newdata, 6, prop.score.star, prog.score.star)
    Double.estimator[j]=SP.inference.under(count.mat = count.mat, eta)$risk.diff
    
    # 4. Block
    block.mat = Block.set(newdata, bsize = bsize)
    Block.estimator[j] = Block.inference.under(block.mat, eta)$risk.diff
    
    # 5. Naive estimator
    ipw.weight = newdata$trt_s / prop.score.star - (1 - newdata$trt_s) / (1 - prop.score.star)
    IPW.estimator[j] = mean(newdata$y * ipw.weight)
    or.model = glm(y ~ trt_s + x1 + x2 + x3 + x4, data = newdata, family = "binomial", x = TRUE)
    or.y1.predict = predict(or.model, data.frame(trt_s = rep(1, n), x1 = newdata$x1, x2 = newdata$x2, x3 = newdata$x3, x4 = newdata$x4), type = "response")
    or.y0.predict = predict(or.model, data.frame(trt_s = rep(0, n), x1 = newdata$x1, x2 = newdata$x2, x3 = newdata$x3, x4 = newdata$x4), type = "response")
    OR.estimator[j] = mean(or.y1.predict - or.y0.predict)
  }
  estimator = cbind(IPW.estimator,OR.estimator,ML.estimator,Strat.prop.estimator,Strat.prog.estimator,Block.estimator,Double.estimator)-check
  abias.col = abs(apply(estimator, 2, mean))
  rmse.col = sqrt(apply(estimator^2, 2, mean))
  result.mat[i,c(1,3,5,7,9,11,13)] = abias.col
  result.mat[i,c(2,4,6,8,10,12,14)] = rmse.col
}

########################################################
### Table 2 - Simulation Results (with all values multiplied by 100)

result.mat * 100
########################################################