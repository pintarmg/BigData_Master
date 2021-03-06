## microfinance network 
## data from BANERJEE, CHANDRASEKHAR, DUFLO, JACKSON 2012

## data on 8622 households
hh <- read.csv("microfi_households.csv", row.names="hh")
hh$village <- factor(hh$village)

## We'll kick off with a bunch of network stuff.
## This will be covered in more detail in lecture 6.
## get igraph off of CRAN if you don't have it
#install.packages("igraph")
## this is a tool for network analysis
## (see http://igraph.sourceforge.net/)
library(igraph)
edges <- read.table("microfi_edges.txt", colClasses="character")
## edges holds connections between the household ids
hhnet <- graph.edgelist(as.matrix(edges))
hhnet <- as.undirected(hhnet) # two-way connections.

## igraph is all about plotting.  
V(hhnet) ## our 8000+ household vertices
## Each vertex (node) has some attributes, and we can add more.
V(hhnet)$village <- as.character(hh[V(hhnet),'village'])
## we'll color them by village membership
vilcol <- rainbow(nlevels(hh$village))
names(vilcol) <- levels(hh$village)
V(hhnet)$color = vilcol[V(hhnet)$village]
## drop HH labels from plot
V(hhnet)$label=NA

# graph plots try to force distances proportional to connectivity
# imagine nodes connected by elastic bands that you are pulling apart
# The graphs can take a very long time, but I've found
# edge.curved=FALSE speeds things up a lot.  Not sure why.

## we'll use induced.subgraph and plot a couple villages 
village1 <- induced.subgraph(hhnet, v=which(V(hhnet)$village=="1"))
village33 <- induced.subgraph(hhnet, v=which(V(hhnet)$village=="33"))

# vertex.size=3 is small.  default is 15
plot(village1, vertex.size=3, edge.curved=FALSE)
plot(village33, vertex.size=3, edge.curved=FALSE)

######  now, on to your homework stuff

library(gamlr)

## match id's; I call these 'zebras' because they are like crosswalks
zebra <- match(rownames(hh), V(hhnet)$name)

## calculate the `degree' of each hh: 
##  number of commerce/friend/family connections
degree <- degree(hhnet)[zebra]
names(degree) <- rownames(hh)
degree[is.na(degree)] <- 0 # unconnected houses, not in our graph

##[1] I'd transform degree to create our treatment variable d. What would 
##you do and why?

##log degree
logd <- log(1+degree)
d <-as.matrix(logd)
colnames(d) <- "d"
par(mfrow=c(1,2))
hist(degree, main="Histogram of Degree", col="red")
hist(logd, main="Histogram of log(1 + Degree)", col="green")

##[2] Build a model to predict d from x, our controls. Comment on how tight
##the fit is and what that implies for estimation and treatment

##get variables and run treatment regression
x1 <- hh
x1$loan <- NULL
x1$d <- NULL
source("naref.R")
naref(x1)
x <- sparse.model.matrix(~., data=x1)[,-1]
treat <- gamlr(x,d,lambda.min.ratio=1e-4)
plot(treat)
dhat <- predict(treat, x, type="response")
colnames(dhat) <- "dhat"
###
sum(coef(treat)!=0)
par(mfrow=c(1,1))
plot(dhat,d,bty="n",pch=21,bg=2, xlab="d hat values", ylab="d values",
	main="Predicting d with controls, R^2= 8.2%") 
cor(drop(dhat),d)^2


##[3] Use predictions from [2] as an estimator for effect of d on loan

##MK-full regression
l <- as.matrix(hh$loan)
row.names(l) <- attr(hh,"row.names")
causal <- gamlr(cBind(d,dhat,x),l,free=2,family="binomial", lambda.min.ratio=1e-6)
sum(coef(causal)!=0)
summary(coef(causal)["d",])
cv.causal <- cv.gamlr(cBind(d,dhat,x),l,free=2,family="binomial", lamdba.min.ratio=1e-6)
sum(coef(cv.causal)!=0)
coef(cv.causal)["d",]
######Note, getting big difference between these two models
plot(causal)
ll <- log(causal$lambda) ## the sequence of lambdas
n <- nrow(l)
par(mfrow=c(1,2))
plot(cv.causal)
plot(ll, AIC(causal)/n, 
     xlab="log lambda", ylab="IC/n", pch=21, bg="orange")
abline(v=ll[which.min(AIC(causal))], col="orange", lty=3)
abline(v=ll[which.min(BIC(causal))], col="green", lty=3)
abline(v=ll[which.min(AICc(causal))], col="black", lty=3)
points(ll, BIC(causal)/n, pch=21, bg="green")
points(ll, AICc(causal)/n, pch=21, bg="black")
legend("topleft", bty="n",
       fill=c("black","orange","green"),legend=c("AICc","AIC","BIC"))



##[4] Compare the results from [3] to those from a straight (naive) lasso
##for loan on d and x. Explain why they are similar or different.

##MK-Naive Regression
naive <- gamlr(cbind(d,x),l,family="binomial")
plot(naive)
coef(naive)["d",]

##[5] Bootstrap your estimator for [3] and describe the uncertainty.
gamb <- c()
for(b in 1:200){
  ib <- sample(1:n, n, replace=TRUE)
  xb <- x[ib,]
  db <- d[ib]
  lb <- l[ib]
  treatb <- gamlr(xb,db,lambda.min.ratio=1e-6)
  dhatb <- predict(treatb, xb, type="response")
  
  fitb <- gamlr(cBind(db,dhatb,xb),lb,free=2,lambda.min.ratio=1e-6)
  gamb <- c(gamb,coef(fitb)["db",])
  print(b)
}
summary(gamb)
hist(gamb)
sd(gamb)
##[+] Can you think of how you'd design an experiement to estimate the 
##the treatment effect of newtork degree?

## if you run a full glm, it takes forever and is an overfit mess
summary(full <- glm(d ~ ., data=x, family="binomial"))
# Warning messages:
# 1: glm.fit: algorithm did not converge 
# 2: glm.fit: fitted probabilities numerically 0 or 1 occurred 
