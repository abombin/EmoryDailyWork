library(fitdistrplus)
library(nortest)
library(glmmTMB)
library(MASS)
library(rstatix)
library(dplyr)
library(pscl)
library(car)



ShPi = function(targDf, freqCol) {
  combPi = numeric()
  for ( i in 1:nrow(targDf) ) {
    curFreq = targDf[i, ][[freqCol]]
    if ( curFreq == 0) {
      pi = 0
    } else {
      pi = curFreq * log(curFreq)
    }
    combPi = c(combPi, pi)
  }
  return(combPi)
}

getShannon = function(df) {
  allSamples = character()
  allShannon = numeric()
  allDepth = numeric()
  samplesList = unique(df$Sample)
  for (curSample in samplesList) {
    curDf = df[df$Sample == curSample,]
    curDepth = unique(curDf$meandepth)
    curShannon = -1 * sum(curDf$Pi.Ln.Pi.)
    allSamples = c(allSamples, curSample)
    allShannon = c(allShannon, curShannon)
    allDepth = c(allDepth, curDepth)
  }
  combDat = data.frame(allSamples, allShannon, allDepth)
  colnames(combDat) = c("Sample", "Shannon", "meandepth")
  return(combDat)
}

varList = c("Ct_depth_adj", "Ct_value","vax_doses_received", "meandepth", "days_since_last_vax", "days_post_symptom_onset", "disease_severity")
runSpearman = function(df, varList, testVar) {
  Variable = character()
  Estimate = numeric()
  Pval = numeric()
  curResp = df[[testVar]]
  for (i in varList ) {
    #print(i)
    curPredict = df[[i]]
    curCor = cor.test(curResp, curPredict, method = "spearman")
    cur_cor_coef = curCor$estimate
    cur_pval = curCor$p.value
    Variable = c(Variable, i)
    Estimate = c(Estimate, cur_cor_coef)
    Pval = c(Pval, cur_pval)
  }
  combDat = data.frame(Variable, Estimate, Pval)
}

runWilcox = function(curPred, combShannon) {
  wilcForm = as.formula(paste("Shannon ~", curPred ))
  wilcox_res<-combShannon %>% rstatix::pairwise_wilcox_test(wilcForm, p.adjust.method = "fdr")
  sumRes = result <- aggregate(wilcForm, data = combShannon, FUN = mean)
  colnames(sumRes)[1] = "Group"
  combDiff = numeric()
  for (i in 1:nrow(wilcox_res)) {
    group1 =  wilcox_res$group1[i]
    group2 = wilcox_res$group2[i]
    curDiff = sumRes$Shannon[sumRes$Group == group1] - sumRes$Shannon[sumRes$Group == group2]
    combDiff= c(combDiff, curDiff)
  }
  wilcox_res$Groups_difference = combDiff
  wilcox_res[wilcox_res$n1 >= 4 & wilcox_res$n2 >= 4, ]
  colnames(wilcox_res)[1] = "Variable"
  
  sel_columns = c("Variable", "group1", "group2" , "p", "Groups_difference")
  wilcox_res =  wilcox_res[, sel_columns]
  
  return(wilcox_res)
}

metadat = read.csv("Final_vaxbt_dataset_AP_metadata.csv")
metadatFilt = unique(metadat[, c("AP_lab_id", "Ct_value", "WHO_variant", "vax_doses_received", "days_since_last_vax", "days_post_symptom_onset", "disease_severity" )])
metadatFilt[metadatFilt == ""] <- NA
metadatFilt[metadatFilt == "."] <- NA
metadatFilt$Sample1 = gsub('_', "-", metadatFilt$AP_lab_id)
metadatFilt$Sample = gsub('_', "-", metadatFilt$AP_lab_id)


metaseq = read.csv('IntraSnv_results/metaseq_ConsTest_freq_1_0_Predictions.csv')
ampseq = read.csv('IntraSnv_results/ampseq_ConsTest_freq_1_0_Predictions.csv')

#metaseqOverlap = metaseq[metaseq$Origin == "Overlap",]
#ampseqOverlap = ampseq[ampseq$Origin == "Overlap",]

metaseqOverlap = metaseq
ampseqOverlap = ampseq

metaseqOverlap$Pi.Ln.Pi. = ShPi(targDf=metaseqOverlap, freqCol="ALLELE.FREQUENCY")
ampseqOverlap$Pi.Ln.Pi. = ShPi(targDf=ampseqOverlap, freqCol="ALLELE.FREQUENCY")

# calculate shannon diversity 
metaseqOverlapShan = getShannon(df=metaseqOverlap)
ampseqOverlapShan = getShannon(df = ampseqOverlap)

# add metadata
metaCombShan = plyr::join(metaseqOverlapShan, metadatFilt, by = "Sample", type = "left", match = 'all')
ampCombShan = plyr::join(ampseqOverlapShan, metadatFilt, by = "Sample", type = "left", match = 'all')

metaCombShan = metaCombShan[!is.na(metaCombShan$AP_lab_id),]
ampCombShan = ampCombShan[!is.na(ampCombShan$AP_lab_id),]

columns_to_check <- c("Ct_value", "vax_doses_received", "days_since_last_vax", "days_post_symptom_onset", "disease_severity")
metaCombShan[columns_to_check] <- lapply(metaCombShan[columns_to_check], as.numeric)
ampCombShan[columns_to_check] <- lapply(ampCombShan[columns_to_check], as.numeric)

metaCombShan$Ct_depth_adj = metaCombShan$Ct_value / metaCombShan$meandepth
ampCombShan$Ct_depth_adj = ampCombShan$Ct_value / ampCombShan$meandepth

# add vaccination status
metaCombShan$Vaccinated = NA
metaCombShan$Vaccinated[metaCombShan$vax_doses_received == 0]<-"No"
metaCombShan$Vaccinated[metaCombShan$vax_doses_received > 0]<-"Yes"

ampCombShan$Vaccinated = NA
ampCombShan$Vaccinated[ampCombShan$vax_doses_received == 0]<-"No"
ampCombShan$Vaccinated[ampCombShan$vax_doses_received > 0]<-"Yes"

# run tests
ShanCorMeta = runSpearman(df=metaCombShan, varList=varList, testVar="Shannon")
ShanCorAmp = runSpearman(df=ampCombShan, varList=varList, testVar="Shannon")

wilcVaxMeta = runWilcox(curPred ="vax_doses_received", combShannon= metaCombShan)
wilcVaxAmp = runWilcox(curPred ="vax_doses_received", combShannon= ampCombShan)

wilcVax_2_Meta = runWilcox(curPred ="Vaccinated", combShannon= metaCombShan)
wilcVax_2_Amp = runWilcox(curPred ="Vaccinated", combShannon= ampCombShan)

wilcVarMeta = runWilcox(curPred ="WHO_variant", combShannon= metaCombShan)
wilcVarAmp = runWilcox(curPred ="WHO_variant", combShannon= ampCombShan)


# evaluate all samples together
combShannon = rbind(metaCombShan, ampCombShan)

ShanCorAll = runSpearman(df=combShannon, varList=varList, testVar="Shannon")
wilcVaxAll = runWilcox(curPred ="vax_doses_received", combShannon= combShannon)
wilcVax_2_All = runWilcox(curPred ="Vaccinated", combShannon= combShannon)

wilcVarAll = runWilcox(curPred ="WHO_variant", combShannon= combShannon)


DisSevWilcox = runWilcox(curPred ="disease_severity", combShannon= combShannon)

# additional tests
vaccShan = combShannon[combShannon$Vaccinated == "Yes",]
ShanCorVacs = runSpearman(df=vaccShan, varList=varList, testVar="Shannon")

