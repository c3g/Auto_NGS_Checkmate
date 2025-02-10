library(data.table)
library(Hmisc)
library(tidyverse)

file="Samples.csv"

ncm_list <- read.csv(file,header=T)
ncm <- lapply(ncm_list$ncm_path,read.delim)
names(ncm) <- paste0(gsub(".ncm","",basename(ncm_list$ncm_path)),"_L00",ncm_list$lane)
if (sum(sapply(ncm,nrow)!=21039) > 0) {
  incomplete <- names(ncm)[sapply(ncm,nrow)!=21039]
  cat("Warning: incomplete ncm files")
  print(incomplete)
}
## remove ones that don't have 21039 rows
ncm <- ncm[sapply(ncm,nrow)==21039]

ncm <- lapply(ncm,function(x) x[,"vaf"])


ncm_matrix <-do.call(cbind,ncm)
#colnames(ncm_matrix) <- gsub(".vaf","",colnames(ncm_matrix))
#ncm_matrix <- vaf_matrix
corr <- rcorr(ncm_matrix)

flattenCorrMatrix <- function(cormat) {
  ut <- upper.tri(cormat)
  data.frame(
    row = rownames(cormat)[row(cormat)[ut]],
    column = rownames(cormat)[col(cormat)[ut]],
    cor  =(cormat)[ut]
  )
}


data <- flattenCorrMatrix(cormat = corr$r)

colnames(data) <- c("Readset1","Readset2","Correlation")
data$Correlation <- round(data$Correlation,4)


dirs <- data.frame(Readset=paste0(ncm_list$sample_name,"_L00",ncm_list$lane),Run=ncm_list$run_name)
duplicates <- dirs[duplicated(dirs$Readset)|duplicated(dirs$Readset,fromLast = T),]
if(nrow(duplicates)>0) {
  warning("dataset contains readsets from muliple runs")
  print(duplicates)
  cat("will assign first run")
}

setDT(data)

#
data[, `:=`(Sample1 = str_remove(Readset1, "_*L00[1-8]_*"),
            Sample2 = str_remove(Readset2, "_*L00[1-8]_*"))]

data <- data[Sample1!=Sample2]           

data[,`:=`(Run1 = sapply(Readset1, function(x) dirs[dirs$Readset == x, "run"][1]),
           Run2 = sapply(Readset2, function(x) dirs[dirs$Readset == x, "run"][1]))]


data2 <- data[, .(Correlation = min(Correlation),
                  Run1 = unique(Run1),
                  Run2 = unique(Run2)),
              by = .(Sample1, Sample2)]


saveRDS(data2,file = file.path(out,"Correlation_dt.rds")) 