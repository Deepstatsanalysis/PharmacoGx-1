########################
## Benjamin Haibe-Kains
## All rights Reserved
## October 23, 2013
########################

#	Normalize and import all data from Connectivity Map

`RMAnormalizationCMAP` <- 
function (gene=TRUE, downloadFiles=TRUE, datapath= file.path("data", "CMAP"), rawpath = file.path(datapath, "cel")) {
  
  # rm(list=ls())

  set.seed(54321)
 
  ## number of cpu cores available for the analysis pipeline
  ## set to 'NULL' if all the available cores should be used

  myRlib <- file.path("temp", "Rlib")
  if(!file.exists(myRlib)) { dir.create(myRlib, showWarnings=FALSE) }

  respath <- file.path("temp")
  if(!file.exists(respath)) { dir.create(respath, showWarnings=FALSE) }
  
  if(!file.exists(datapath)) { dir.create(datapath, showWarnings=FALSE) }
  if(!file.exists(rawpath)) { dir.create(rawpath, showWarnings=FALSE) }

 # datapath <- file.path("data", "CMAP")
 # rawpath <- file.path(datapath, "cel")

  badchars <- "[:]|[-]|[+]|[*]|[%]|[$]|[#]|[{]|[}]|[[]|[]]|[|]|[\\^]|[/]|[\\]|[.]|[_]|[ ]"

  # normalization
  if (gene){
    myfn <- file.path(respath, "cmap_rma_ENTREZ.RData")
  } else {
    myfn <- file.path(respath, "cmap_rma.RData")
  }

  if(!file.exists(myfn)) {
    ## read cel files data

    ## CEL file names
    celfn <- list.files(rawpath, full.names=TRUE)
    celfns <- list.files(rawpath, full.names=FALSE)
    
    if (!length(celfn)){
      if(!downloadFiles){
        stop("Cel Files not found! Either provide the cel files or set downloadFiles to TRUE to have them automatically downloaded to rawpath.")
      } else {
        filesTodownload <- getURL("ftp://ftp.broad.mit.edu/pub/cmap/",dirlistonly = TRUE)
        filesTodownload <- strsplit(filesTodownload, split='\n')
        filesTodownload <- grep(x=filesTodownload[[1]], pattern="cmap_build02", value=TRUE)
        for (fn in filesTodownload){
          download.file(url=file.path("ftp://ftp.broad.mit.edu/pub/cmap/", fn), destfile=file.path(rawpath, fn))
          unzip(zipfile=file.path(rawpath, fn),exdir=rawpath)
          file.remove(file.path(rawpath, fn))
        }
        for (fn in list.files(path=rawpath)){
          bunzip2.default(filename=file.path(rawpath, fn))
          file.remove(file.path(rawpath, fn))
        }
        celfn <- list.files(rawpath, full.names=TRUE)
        celfns <- list.files(rawpath, full.names=FALSE)
      }
    }  
      
    
    ## experiments' names
    names(celfn) <- gsub(".CEL|.CEL.GZ", "", toupper(list.celfiles(rawpath)))

    ## identify the Affymetrix platform used for each experiment
    if(!file.exists("temp/cmap_cel_chiptype.RData")) {
    	chiptype.orig <- sapply(celfn, celfileChip)
    	if(!all(is.element(names(table(chiptype.orig)), c("HG-U133A", "HT_HG-U133A", "U133AAofAv2")))) { stop("unknown Affymetrix platform in the dataset!") }
    	## convert U133AAofAv2 CEL files to HT_HG-U133A platform
    	## create a new cel directory and uncompress all CEL files
    	nd <- "cel3"
    	if(!file.exists(sprintf("data/CMAP/%s", nd))) { system(sprintf("mkdir data/CMAP/%s", nd)) }
    	#system("cp data/CMAP/cel/* data/CMAP/cel2/")
    	celfn2 <- list.celfiles(sprintf("data/CMAP/%s", nd), full.names=FALSE)
    	iix <- !is.element(celfns, celfn2)
    	if(any(iix)) {
    		ccel <- apply(cbind("celfn"=celfn[iix], "chiptype"=chiptype.orig[iix]), 1, function(x) {
    			tt <- unlist(strsplit(x[1], "/"))
    			mypath <- paste(tt[-length(tt)], collapse="/")
    			myfn <- tt[length(tt)]
    			if(x[2] == "U133AAofAv2") {
    				tt <- unlist(strsplit(x[1], "/"))
    				mypath <- paste(tt[-length(tt)], collapse="/")
    				myfn <- tt[length(tt)]
    				tt <- strsplit(myfn, "[.]")[[1]]
    				tt <- tt[length(tt)]
    				if(tt == "gz") {
    					tt <- strsplit(myfn, "[.]")[[1]]
    					myfn <- paste(tt[-length(tt)], collapse=".")
    					system(sprintf("gunzip %s", x, myfn))
    				}
    				rr <- affxparser::convertCel(filename=sprintf("%s/%s", mypath, myfn), outFilename=sprintf("data/CMAP/%s/%s", nd, myfn), newChipType="HT_HG-U133A", validate=TRUE)
    				system(sprintf("gzip %s", sprintf("%s/%s", mypath, myfn)))
    				system(sprintf("gzip %s", rr))
    			} else { system(sprintf("cp -f %s data/CMAP/%s/", x[1], nd)) }
    		})
    	}
    	## new CEL file names
    	rawpath <- sprintf("data/CMAP/%s", nd)
    	celfn <- list.celfiles(rawpath, full.names=TRUE)
    	## experiments' names
    	names(celfn) <- gsub(".CEL|.CEL.GZ", "", toupper(list.celfiles(rawpath)))
    	chiptype <- sapply(celfn, celfileChip)
    	chiptype <- chiptype[names(celfn)]
    	chiptype.orig <- chiptype.orig[names(celfn)]
    	save(list=c("chiptype.orig", "chiptype", "celfn"), file="temp/cmap_cel_chiptype.RData")
    } else { load("temp/cmap_cel_chiptype.RData") }

    ##---------------	ConnectivityMap drug information -> druginfo.cmap
    if(!file.exists("temp/cmap_sampleinfo_druginfo.RData")) {
    	sampleinfo <- read.csv("data/CMAP/cmap_instances_02.csv", stringsAsFactors=FALSE)
    	rownames(sampleinfo) <- gsub("^'", "",  toupper(sampleinfo[ ,"perturbation_scan_id"]))
    	sampleinfo[ ,"perturbation_scan_id"] <- gsub("^'", "",  toupper(sampleinfo[ ,"perturbation_scan_id"]))
    	sampleinfo[ ,"vehicle_scan_id4"] <- gsub("^'", "",  toupper(sampleinfo[ ,"vehicle_scan_id4"]))
    	sampleinfo[sampleinfo == "" | sampleinfo == " " | sampleinfo == "Unknown"] <- NA
    	druginfo <- sampleinfo[ , c("cmap_name","INN1","vendor","catalog_number","catalog_name")]
    	sampleinfo <- sampleinfo[ , !is.element(colnames(sampleinfo), c("cmap_name","INN1","vendor","catalog_number","catalog_name")), drop=FALSE]


    	## Add data to druginfo
    	##	Read file from Lamb with other compound indentifiers
    	druginfo_lamb <- read.csv("data/CMAP/cmap_CBID_Lamb.csv", stringsAsFactors=FALSE)
    	## check 100% match
    	if(!all(druginfo_lamb$cmap_name %in% druginfo$cmap_name)) { stop("some CMAP drugs are uncharacterized (CBID)!") }
    	druginfo$cmap_name_id <- druginfo_lamb[match(druginfo$cmap_name, druginfo_lamb$cmap_name, nomatch = NA), "cmap_name_id"]
    	druginfo$CBID         <- druginfo_lamb[match(druginfo$cmap_name, druginfo_lamb$cmap_name, nomatch = NA), "CBID"]
    	## generate a unique id per drug
    	druginfo$drug_id <- paste("drug.cmap", as.numeric(as.factor(druginfo$cmap_name)), sep=".")
    	sampleinfo <- data.frame(sampleinfo, "cmap_name"=druginfo$cmap_name, "drug_id"=as.character(druginfo$drug_id))
    	## keep only the unique drugs
    	druginfo <- druginfo[!duplicated(druginfo$cmap_name), , drop=FALSE]
    	rownames(druginfo) <- druginfo$drug_id


    	## add SMILES and other information about perturbagens
    	#	load ChemBank data in MLD MOL (.sdf) and convert into matrix
    	CBdata <- load.molecules(c("data/CMAP/CmapChembankCompounds.sdf")) # molecule data
    	smiles <- CBID  <- inchi <- NULL
    	for (x in  1:length(CBdata)) {
    		CBID    <- c(CBID, get.title(CBdata[[x]]))
    		smiles  <- c(smiles, get.smiles(CBdata[[x]]))
    		inchi   <- c(inchi, get.properties(CBdata[[x]])$InChI)	
    	}
    	druginfo_CBID <-data.frame(smiles = smiles[,drop=FALSE],CBID = CBID[,drop=FALSE],inchi = inchi[,drop=FALSE])
    	#	Add Chembank data to druginfo
    	druginfo$CBID2  <-druginfo_CBID[match(druginfo$CBID, druginfo_CBID$CBID, nomatch = NA),"CBID" ] #! remove when check completed
    	druginfo$smiles <-druginfo_CBID[match(druginfo$CBID, druginfo_CBID$CBID),"smiles" ]
    	druginfo$smiles <- as.character(druginfo$smiles)
    	druginfo$inchi  <- druginfo_CBID[match(druginfo$CBID, druginfo_CBID$CBID, nomatch = NA),"inchi" ]

    	## intersection between filenames and sampleinfo data
    	tt <- data.frame(matrix(NA, nrow=length(celfn), ncol=ncol(sampleinfo), dimnames=list(names(celfn), colnames(sampleinfo))), stringsAsFactors=FALSE)
    	tt <- genefu::setcolclass.df(df=tt, colclass=sapply(sampleinfo, class), factor.levels=sapply(sampleinfo, levels))
    	myx <- intersect(names(celfn), rownames(sampleinfo))
    	if(length(myx) < nrow(sampleinfo)) { stop("some CEL files are absent!") }
    	tt[myx, ] <- sampleinfo[myx, , drop=FALSE]
    	sampleinfo <- tt
    	sampleinfo <- data.frame("samplename"=rownames(sampleinfo), "chiptype"=chiptype, sampleinfo)
	
    	## populate sampleinfo with information regarding the controls
    	addinfo <- data.frame(matrix(NA, nrow=nrow(sampleinfo), ncol=2, dimnames=list(rownames(sampleinfo), c("xptype", "xpassoc"))))
    	addinfo[!is.na(sampleinfo[ , "instance_id"]), "xptype"] <- "perturbation"
    	addinfo[is.na(sampleinfo[ , "instance_id"]), "xptype"] <- "control"
    	xpn <- rownames(addinfo)[addinfo[ , "xptype"] == "perturbation"]
    	ctrln <- rownames(addinfo)[addinfo[ , "xptype"] == "control"]
    	#nn.map <- NULL
    	ppn <- seq(5, 100, by=5)
    	pp <- 1
    	for(i in 1:length(xpn)) {
    		if(pp < length(ppn) && (i / length(xpn)) >= (ppn[pp] / 100)) {
    			message(sprintf("control xps identification: %i%% completed", ppn[pp]))
    			pp <- pp + 1
    		}
    		vn <- drop(sapply(strsplit(sampleinfo[xpn[i], "vehicle_scan_id4"], "[.]"), function(x) { return(x[!is.na(x) & x != "" & x != " "]) }))
    		vn <- vn[nchar(vn) == 3]
    		if(length(vn) == 0) { cxpn <- sampleinfo[xpn[i], "vehicle_scan_id4"] } else { cxpn <- paste(strsplit(xpn[i], "[.]")[[1]][1], vn, sep=".") }
    		if(!all(is.element(cxpn, ctrln))) { stop("some controls are missing!") }
    		addinfo[xpn[i], "xpassoc"] <- paste(cxpn, collapse="///")
    		for(j in 1:length(cxpn)) {
    			if(is.na(sampleinfo[cxpn[j], "batch_id"])) { sampleinfo[cxpn[j], "batch_id"] <- sampleinfo[xpn[i], "batch_id"] }
    			if(is.na(sampleinfo[cxpn[j], "cell_id"])) { sampleinfo[cxpn[j], "cell_id"] <- sampleinfo[xpn[i], "cell_id"] }
    			if(is.na(sampleinfo[cxpn[j], "vehicle_scan_id4"])) { sampleinfo[cxpn[j], "vehicle_scan_id4"] <- sampleinfo[xpn[i], "vehicle_scan_id4"] }
    			if(is.na(sampleinfo[cxpn[j], "scanner"])) { sampleinfo[cxpn[j], "scanner"] <- sampleinfo[xpn[i], "scanner"] }
    			if(is.na(sampleinfo[cxpn[j], "vehicle"])) { sampleinfo[cxpn[j], "vehicle"] <- sampleinfo[xpn[i], "vehicle"] }
    			if(is.na(sampleinfo[cxpn[j], "array3"])) { sampleinfo[cxpn[j], "array3"] <- sampleinfo[xpn[i], "array3"] }
    			sampleinfo[cxpn[j], "concentration_M"] <- sampleinfo[cxpn[j], "duration_h"] <- 0
    			if(is.na(sampleinfo[cxpn[j], "perturbation_scan_id"])) { sampleinfo[cxpn[j], "perturbation_scan_id"] <- sampleinfo[xpn[i], "perturbation_scan_id"] } else { sampleinfo[cxpn[j], "perturbation_scan_id"] <- paste(sampleinfo[cxpn[j], "perturbation_scan_id"], sampleinfo[xpn[i], "perturbation_scan_id"], sep="///") }

    			if(is.na(addinfo[cxpn[j], "xpassoc"])) { addinfo[cxpn[j], "xpassoc"] <- xpn[i] } else { addinfo[cxpn[j], "xpassoc"] <- paste(addinfo[cxpn[j], "xpassoc"], xpn[i], sep="///") }
    		}
    		#nn.map <- c(nn.map, list(cxpn))
    		#names(nn.map)[length(nn.map)] <- xpn[i]
    	}
    	## reorder each associated experiments (xpassoc)
    	addinfo[ ,"xpassoc"] <- sapply(addinfo[ ,"xpassoc"], function(x) {
    		return(paste(sort(unlist(strsplit(x, "///"))), collapse="///"))
    	})
    	## idem for perturbation_scan_id
    	sampleinfo[ ,"perturbation_scan_id"] <- sapply(sampleinfo[ ,"perturbation_scan_id"], function(x) {
    		return(paste(sort(unlist(strsplit(x, "///"))), collapse="///"))
    	})
    	sampleinfo <- data.frame(sampleinfo, addinfo, "celfilename"=paste(names(celfn), "CEL", sep="."))
    	save(list=c("sampleinfo", "druginfo"), file="temp/cmap_sampleinfo_druginfo.RData")
    } else { load("temp/cmap_sampleinfo_druginfo.RData") }
    sampleinfo.cmap <- sampleinfo
    druginfo.cmap <- druginfo

    ## HG-U133A
    platf <- "HG-U133A"
    message(sprintf("Affymetrix platform %s", platf))
    ### load frmavectors
    #data(hgu133afrmavecs)

    ## format the data using rma
    if(!file.exists("temp/cmap_hgu133a_rma.RData")) {
    	## select platform
    	message(sprintf("Normalization of %s CEL files", platf))
    	myx <- which(is.element(chiptype, c(platf)))
    	celfnt <- celfn[myx]
      ## rma
      datat <- affy::just.rma(filenames=celfnt, verbose=TRUE)
      colnames(exprs(datat)) <- names(celfnt)
    	## rename objects
    	data.hgu133a <- exprs(datat)[,rownames(sampleinfo.cmap)[myx] , drop=FALSE]
    	rm(list=c("datat"))
    	gc()
    	data.hgu133a <- t(data.hgu133a)
    	save(list=c("data.hgu133a", "sampleinfo.cmap", "druginfo.cmap"), compress=TRUE, file="temp/cmap_hgu133a_rma.RData")
    } else { load("temp/cmap_hgu133a_rma.RData") }
    #save(list=ls(), compress=TRUE, file="ws.RData")

    ## HT_HG-U133A
    platf <- "HT_HG-U133A"
    message(sprintf("Affymetrix platform %s", platf))
    #data(hthgu133afrmavecs)

    ## format the data using rma
    if(!file.exists("temp/cmap_hthgu133a_rma.RData")) {
    	message(sprintf("Normalization of %s CEL files", platf))
    	## select platform
    	myx <- which(is.element(chiptype, c(platf)))
    	celfnt <- celfn[myx]
    	## rma
    	datat <- affy::just.rma(filenames=celfnt, verbose=TRUE)
    	colnames(exprs(datat)) <- names(celfnt)
    	## rename objects
    	data.hthgu133a <- exprs(datat)[,rownames(sampleinfo.cmap)[myx] , drop=FALSE]
    	rm(list=c("datat", "rr2", "abatch"))
    	gc()
    	data.hthgu133a <- t(data.hthgu133a)
    	save(list=c("data.hthgu133a", "sampleinfo.cmap", "druginfo.cmap"), compress=TRUE, file="temp/cmap_hthgu133a_rma.RData")
    } else { load("temp/cmap_hthgu133a_rma.RData") }
    #save(list=ls(), compress=TRUE, file="ws.RData")
    
    probeset.common <- intersect(colnames(data.hgu133a), colnames(data.hthgu133a))

    # filter data
    data.hgu133a <- data.hgu133a[ , probeset.common, drop=FALSE]
    data.hthgu133a <- data.hthgu133a[ , probeset.common, drop=FALSE]

    # annotations for hgu133a
    mart.db <- biomaRt::useMart("ENSEMBL_MART_ENSEMBL", host="www.ensembl.org", dataset="hsapiens_gene_ensembl")
    # select the best probe for a single gene
    js <- jetset::jscores(chip="hgu133a", probeset=probeset.common)
    js <- js[probeset.common, , drop=FALSE]
    # identify the best probeset for each entrez gene id
    geneid1 <- as.character(js[ ,"EntrezID"])
    names(geneid1) <- rownames(js)
    geneid2 <- sort(unique(geneid1))
    names(geneid2) <- paste("geneid", geneid2, sep=".")
    gix1 <- !is.na(geneid1)
    gix2 <- !is.na(geneid2)
    geneid.common <- intersect(geneid1[gix1], geneid2[gix2])
    # probes corresponding to common gene ids
    gg <- names(geneid1)[is.element(geneid1, geneid.common)]
    gid <- geneid1[is.element(geneid1, geneid.common)]
    # duplicated gene ids
    gid.dupl <- unique(gid[duplicated(gid)])
    gg.dupl <- names(geneid1)[is.element(geneid1, gid.dupl)]
    # unique gene ids
    gid.uniq <- gid[!is.element(gid, gid.dupl)]
    gg.uniq <- names(geneid1)[is.element(geneid1, gid.uniq)]
    # which are the best probe for each gene
    js <- data.frame(js, "best"=FALSE)
    js[gg.uniq, "best"] <- TRUE
    # data for duplicated gene ids
    if(length(gid.dupl) > 0) {	
    	## use jetset oevrall score to select the best probeset
    	myscore <- js[gg.dupl,"overall"]
    	myscore <- cbind("probe"=gg.dupl, "gid"=geneid1[gg.dupl], "score"=myscore)
    	myscore <- myscore[order(as.numeric(myscore[ , "score"]), decreasing=TRUE, na.last=TRUE), , drop=FALSE]
    	myscore <- myscore[!duplicated(myscore[ , "gid"]), , drop=FALSE]
    	js[myscore[ ,"probe"], "best"] <- TRUE
    }
    # more annotations from biomart
    ugid <- sort(unique(js[ ,"EntrezID"]))
    ss <- "entrezgene"
    gene.an <- biomaRt::getBM(attributes=c(ss, "ensembl_gene_id", "unigene", "description", "chromosome_name", "start_position", "end_position", "strand", "band"), filters="entrezgene", values=ugid, mart=mart.db)
    gene.an[gene.an == "" | gene.an == " "] <- NA
    gene.an <- gene.an[!is.na(gene.an[ , ss]) & !duplicated(gene.an[ , ss]), , drop=FALSE]
    gene.an <- gene.an[is.element(gene.an[ ,ss], ugid), ,drop=FALSE]
    annot <- data.frame(matrix(NA, nrow=length(probeset.common), ncol=ncol(gene.an)+1, dimnames=list(probeset.common, c("probe", colnames(gene.an)))))
    annot[match(gene.an[ , ss], js[ ,"EntrezID"]), colnames(gene.an)] <- gene.an
    annot[ ,"probe"] <- probeset.common
    colnames(js)[colnames(js) != "best"] <- paste("jetset", colnames(js)[colnames(js) != "best"], sep=".")
    annot <- data.frame(annot, "EntrezGene.ID"=js[ ,"jetset.EntrezID"], js)

    ## merge all the datasets
    fff <- file.path("temp", "cmap_rma.RData")
    if(!file.exists(fff)) {
    data <- rbind(data.hgu133a, data.hthgu133a)
    data <- data[rownames(sampleinfo.cmap), , drop=FALSE]
    data.cmap <- data
    annot.cmap <- annot
    save(list=c("data.cmap", "annot.cmap", "sampleinfo.cmap", "druginfo.cmap"), compress=TRUE, file=fff)
    } else { load(fff) }

#     ## perform a second round of quantile normalization
#     fff <- file.path("temp", "cmap_quantile2_rma.RData")
#     if(!file.exists(fff)) {
#       ## compute the median profile of HT_HG-U133A samples
#       myx <- !is.na(sampleinfo.cmap[ ,"chiptype"]) & sampleinfo.cmap[ ,"chiptype"] == "HT_HG-U133A"
#       tt <- t(apply(data.cmap, 1, sort, decreasing=TRUE))
#       qnormvec.hthgu133acmap <- apply(tt, 2, median, na.rm=TRUE)
#       probe.name <- probeset.common
#       save(list=c("qnormvec.hthgu133acmap", "probe.name"), file=file.path("temp", "cmap_qnormvec_hthgu133a.RData"))
#
#       ## perform the quantile normalization to all samples
#       tt <- t(apply(data.cmap[ , probe.name, drop=FALSE], 1, function(x, y) {
#       	ix <- order(x, decreasing=TRUE)
#       	x[ix] <- y
#       	return(x)
#       }, y=qnormvec.hthgu133acmap))
#       data.cmap <- tt
#       save(list=c("data.cmap", "annot.cmap", "sampleinfo.cmap", "druginfo.cmap"), compress=TRUE, file="temp/cmap_quantile2_rma.RData")
#     }
  
    ## gene-centric data
    fff <- file.path("temp", "cmap_rma_ENTREZ.RData")
    if(!file.exists(fff)) {
      load(file.path("temp", "cmap_rma.RData"))
      ## gene centric data
      myx <- which(annot.cmap[ , "best"])
      myx <- myx[!duplicated(annot.cmap[myx, "jetset.EntrezID"])]
      data.cmap <- data.cmap[ , myx, drop=FALSE]
      annot.cmap <- annot.cmap[myx, , drop=FALSE]
      colnames(data.cmap) <- rownames(annot.cmap) <- paste("geneid", annot.cmap[ ,"jetset.EntrezID"], sep=".")
      save(list=c("data.cmap", "annot.cmap", "sampleinfo.cmap", "druginfo.cmap"), compress=TRUE, file=fff)
    } else { load(fff) }
#     fff <- file.path("temp", "cmap_quantile2_rma_ENTREZ.RData")
#     if(!file.exists(fff)) {
#       load(file.path("temp", "cmap_quantile2_rma.RData"))
#       ## gene centric data
#       myx <- which(annot.cmap[ , "best"])
#       myx <- myx[!duplicated(annot.cmap[myx, "jetset.EntrezID"])]
#       data.cmap <- data.cmap[ , myx, drop=FALSE]
#       annot.cmap <- annot.cmap[myx, , drop=FALSE]
#       colnames(data.cmap) <- rownames(annot.cmap) <- paste("geneid", annot.cmap[ ,"jetset.EntrezID"], sep=".")
#       save(list=c("data.cmap", "annot.cmap", "sampleinfo.cmap", "druginfo.cmap"), compress=TRUE, file=fff)
#     }  
  
  } else { load(myfn) }
  ret <- list("data.cmap"=data.cmap, "annot.cmap"=annot.cmap, "sampleinfo.cmap"=sampleinfo.cmap, "druginfo.cmap"=druginfo.cmap)
  return(ret)
}



  ## end


