precision <- function(data, cutoff) {
  correct.returned <- sum(data$valid[data$prob > cutoff])
  total.returned <- length(which(data$prob > cutoff))

  return(correct.returned/total.returned)
}

recall <- function(data, cutoff) {
  correct.returned <- sum(data$valid[data$prob > cutoff])
  total.correct <- sum(data$valid)

  return(correct.returned/total.correct)
}

f1.plot <- function(data) {
  x <- seq(from=0, to=max(data$prob), length.out=100)
  
  r <- sapply(x, function(x) {recall(data, x)})
  p <- sapply(x, function(x) {precision(data, x)})
  
  f <- 2 * (r * p)/(r + p)
  
  return(data.frame(x=x, p=p, r=r, f=f))
}

trans1 <- read.table("trans1.valid.txt", encoding="UTF-8")
colnames(trans1) <- c("query", "result", "prob", "valid")
trans2 <- read.table("trans2.valid.txt", encoding="UTF-8")
colnames(trans2) <- c("query", "result", "prob", "valid")
#plot(f1.plot(trans2))
