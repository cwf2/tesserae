valdata <- read.table("validation.txt", encoding="UTF-8", header=T, na.strings="NULL")
fields_result <- grep("^trans_", colnames(valdata))
fields_valid <- grep("^valid_", colnames(valdata))

valid.one.row <- function(rec) {
  results <- rec[fields_result]
  valid <- rec[fields_valid]
  mask <- is.na(results) | duplicated(results)
  data.frame(
    query=rep(rec["greek"], sum(! mask)),
    result=results[! mask],
    valid=valid[! mask] == 1
  )
}

valid <- do.call(rbind, apply(valdata, 1, valid.one.row))
row.names(valid) <- NULL