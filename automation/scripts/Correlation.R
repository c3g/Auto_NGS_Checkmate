suppressMessages(library(data.table))
suppressMessages(library(Hmisc))
suppressMessages(library(optparse))
suppressMessages(library(tidyverse))
option_list <- list(make_option(c("-i","--ncm_directory")),
                    make_option(c("-n","--new_samples")),
		    make_option(c("-s","--sample_list")),
		    make_option(c("-o","--out"), default="correlation_dt.rds"))

opt <- parse_args(OptionParser(option_list=option_list))
## Sample files

new_list <- read.csv(opt$new_samples,header=F)		
colnames(new_list) <- c("sample_name","ProjectID","ProjectName","lane","run_name","ncm_path")
if("sample_list" %in% names(opt)) {
old_list <- read.csv(opt$sample_list,header=F)
colnames(old_list) <- c("sample_name","ProjectID","ProjectName","lane","run_name","ncm_path")
ncm_list <- rbind(old_list,new_list)
} else {
 ncm_list <- new_list
}

ncm_list <- distinct(ncm_list)
ncm_files <- list.files(path=opt$ncm_directory,pattern="ncm",full.names=T)
ncm <- lapply(ncm_files,read.delim)
names(ncm) <- gsub(".ncm","",basename(ncm_files))
samples_from_list <- paste0(ncm_list$sample_name,"_L00",ncm_list$lane)

if(length(ncm)!=nrow(ncm_list)) {
warning(paste(length(ncm),"ncm files are present and", nrow(ncm_list), "ncm files are listed"))
missing_from_list <- names(ncm)[!names(ncm) %in% samples_from_list]
missing_files <- samples_from_list[!samples_from_list %in% names(ncm)]
message("samples missing from csv:\n")
print(missing_from_list)
message("files missing \n")
print(missing_files)
ncm <- ncm[names(ncm) %in% samples_from_list]
ncm_list <- ncm_list[samples_from_list %in% names(ncm),]
}
 
if (sum(sapply(ncm,nrow)!=21039) > 0) {
  incomplete <- names(ncm)[sapply(ncm,nrow)!=21039]
  warning("Warning: incomplete ncm files")
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
duplicates <- duplicates[sort(duplicates$Readset),]
if(nrow(duplicates)>0) {
  cat("dataset contains readsets from muliple runs")
  print(duplicates)
  cat("will assign first run")
}

setDT(data)

#
data[, `:=`(Sample1 = str_remove(Readset1, "_*L00[1-8]_*"),
            Sample2 = str_remove(Readset2, "_*L00[1-8]_*"))]

data <- data[Sample1!=Sample2]           
data[,`:=`(Run1 = sapply(Readset1, function(x) dirs[dirs$Readset == x, "Run"][1]),
           Run2 = sapply(Readset2, function(x) dirs[dirs$Readset == x, "Run"][1]))]


data2 <- data[, .(Correlation = min(Correlation),
                  Run1 = unique(Run1),
                  Run2 = unique(Run2)),
              by = .(Sample1, Sample2)]


saveRDS(data2,file = opt$out) 
