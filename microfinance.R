## microfinance network 
## data from BANERJEE, CHANDRASEKHAR, DUFLO, JACKSON 2012

## data on 8622 households
hh <- read.csv(file.choose(), row.names="hh")
hh$village <- factor(hh$village)

## We'll kick off with a bunch of network stuff.
## This will be covered in more detail in lecture 6.
## get igraph off of CRAN if you don't have it
install.packages("igraph")
## this is a tool for network analysis
## (see http://igraph.sourceforge.net/)
library(igraph)
edges <- read.table(file.choose(), colClasses="character")
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
hh$d <- degree > 3
hh$d[hh$d==TRUE] <- 1
hh$d[hh$d==FALSE] <- 0
hh$d
x <- hh
x$village <- NULL


###Matt Olson###
##[1] I'd transform degree to create our treatment variable d. What would 
##you do and why?
hist(degree)##see that the distribution is not normal looks like a 1/x
transdeg <- 1/log(2 + degree)
hist(transdeg)##looks closer to normal


##[2] Build a model to predict d from x, our controls. Comment on how tight
##the fit is and what that implies for estimation and treatment

y <- hh$loan
d <- transdeg
controls <-data.frame(hh[,c(2:9)])
summary(orig <- glm(y ~ d+.,data=controls, family="binomial") )$coef['d',]
###Appears to have a tight fit and should be good estimator 
###and effective for treatment????(read more in the notes)

##[3] Use predictions from [2] as an estimator for effect of d on loan
print(deff <- 2 + (exp(1/(orig$coef['d']))))
####additional connections increase odds of a loan by a factor of ~2?


##[4] Compare the results from [3] to those from a straight (naive) lasso
##for loan on d and x. Explain why they are similar or different.

####having issue here running a lasso, need to put data in sparse matrix
head(controls)
factor(controls$religion)
factor(controls$roof)

x <- 
naive <- gamlr(cBind(d,x),y)
coef(naive)["d",]



##[5] Bootstrap your estimator for [3] and describe the uncertainty.

##[+] Can you think of how you'd design an experiement to estimate the 
##the treatment effect of newtork degree?

## if you run a full glm, it takes forever and is an overfit mess
summary(full <- glm(d ~ ., data=x, family="binomial"))
# Warning messages:
# 1: glm.fit: algorithm did not converge 
# 2: glm.fit: fitted probabilities numerically 0 or 1 occurred 