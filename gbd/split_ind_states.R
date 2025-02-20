################################################################################
## Purpose: Split India states into U/R using NFHS survey values
## Date created:
## Date modified: January 15, 2019
## Author: Austin Carter, aucarter@uw.edu, modified by Deepa Jahagirdar
## Run instructions: Run after EPP-ASM India state locations are run; produces a table identical to EPP-ASM output for India level 5 locs
## Notes:
################################################################################

### Setup
# rm(list=ls())
windows <- Sys.info()[1][["sysname"]]=="Windows"
root <- ifelse(windows,"J:/","/home/j/")
user <- ifelse(windows, Sys.getenv("USERNAME"), Sys.getenv("USER"))
code.dir <- paste0(ifelse(windows, "H:", paste0("/homes/", user)), "/gbdeppaiml/")

## Packages
library(data.table);library(tidyr);library(dplyr);library(parallel)

## Arguments
args <- commandArgs(trailingOnly = TRUE)
if(length(args) > 0) {
  run.name <- args[1]
  decomp.step <- args[2]
} else {

  run.name <- "200713_yuka"
  decomp.step <- 'iterative'
}



### Paths
dir.list <- paste0('/share/hiv/epp_output/gbd20/',run.name,'/compiled/')
prop.path <- paste0('/share/hiv/epp_input/gbd20/art_prop.csv')
pop.dir <- list(paste0('/share/hiv/epp_input/gbd20/',run.name,"/population_single_age/"),
                paste0('/share/hiv/epp_input/gbd20/',run.name,"/population_single_age/india_splitting_locs/"))


### Functions
library(mortdb, lib = "/ihme/mortality/shared/r")


##Find corrent age groups and sex ids to match EPP-ASM output using one location
invisible(sapply(list.files("/share/cc_resources/libraries/current/r/", full.names = T), source))
##reading in one file to pull out the format of the age groups
x = fread(paste0(dir.list,"IND_4841.csv"))
age_groups <- get_ids("age_group")
age_groups[age_group_name=="<1 year",age_group_name := "0"]
x$age = as.factor(as.character(x$age))
get.age.groups = unique(merge(x,age_groups, by.x='age', by.y = 'age_group_name'))[,.(age,age_group_id)]

sex_groups <- get_ids("sex")
sex_groups$sex <- tolower(sex_groups$sex)

prop.dt <- fread(prop.path)[grepl("IND", ihme_loc_id)]
pops <- paste0("/ihme/hiv/epp_input/gbd20/",run.name,"/population_single_age/")



### Tables
loc.table <- data.table(get_locations(hiv_metadata = T))
# Values from NFHS-3 report https://dhsprogram.com/pubs/pdf/FRIND3/FRIND3-Vol1[Oct-17-2008].pdf
nat.urban06 <- 0.35
nat.rural06 <- 0.25

# Values from NFHS-4 report http://rchiips.org/NFHS/NFHS-4Reports/India.pdf
nat.urban15 <- 0.38
nat.rural15 <- 0.17

### Code
### Create minor territories ###
file.list <- list.files(dir.list, "IND_")
locs <- gsub("_under1_splits.csv", "", file.list)
locs <- gsub(".csv", "", locs)
ind.locs <- loc.table[grepl("IND", ihme_loc_id) & level == 4, ihme_loc_id]
missing.locs <- setdiff(ind.locs, unique(locs))
missing.locs.child <- missing.locs

spec.inc.path <- paste0('/ihme/hiv/epp_output/gbd20/', run.name, '/compiled/IND_inc/')
spec.prev.path <- paste0('/ihme/hiv/epp_output/gbd20/', run.name, '/compiled/IND_prev/')
dir.create(spec.inc.path, showWarnings = F)
dir.create(spec.prev.path, showWarnings = F)

ind.locs.epp <- loc.table[grepl("IND",ihme_loc_id) & epp==1,ihme_loc_id]

##Sum counts across populations
all.ind<- lapply(ind.locs.epp, function(loc_i) {
  sum.dt <- fread(paste0(dir.list,loc_i,".csv"))
  print(which(ind.locs.epp == loc_i) / length(ind.locs.epp))
  return(sum.dt)
})
all.ind <- rbindlist(all.ind)
stratum <- colnames(all.ind)[colnames(all.ind) %in% c("age", "sex", "year","run_num")]
cols <- colnames(all.ind)[!colnames(all.ind) %in% stratum]
measures <- cols
x <- all.ind[ ,lapply(.SD,as.numeric), .SDcols=cols]
all.ind <- cbind(x, all.ind[,.(age, sex, year, run_num)])
sum.ind <- all.ind[ ,lapply(.SD,sum), .SDcols=cols, by=stratum]

#
# print("filling in missing locs")
# # for(m_loc in missing.locs){
# #   m_loc1 <- loc.table[ihme_loc_id==m_loc,location_id]
# #   pop <- get_mort_outputs('population', 'estimate', location_id = m_loc1, age_group_ids = unique(get.age.groups$age_group_id), sex_id = c(1,2), year_ids = c(1970:2022))
# #   pop_sa <-  get_mort_outputs('population single year', 'estimate', location_id = m_loc1, age_group_ids = unique(get.age.groups$age_group_id), sex_id = c(1,2), year_ids = c(1970:2022))
# #   setnames(pop_sa, 'population', 'mean')
# #   pop <- rbind(pop[,.(year_id, location_id, ihme_loc_id, sex_id, age_group_id, mean, lower, upper)],
# #                pop_sa[,.(year_id, location_id, ihme_loc_id, sex_id, age_group_id, mean, lower, upper)])
# #   pop <- merge(pop,unique(get.age.groups),by="age_group_id")
# #   pop <- merge(pop,sex_groups,by="sex_id")
# #   setnames(pop,c('year_id'), c('year'))
# #   pop$age <- as.integer(pop$age)
# #   setnames(pop, 'mean', 'population')
# #   combined.pop <- merge(sum.ind,unique(pop[,.(year,sex,age,population)]), by=c('year','sex','age'))
# #   combined.pop$pop.ratio <- combined.pop$population/combined.pop$pop
# #
# #   m_loc_all <- combined.pop[ ,lapply(.SD,"*",pop.ratio), .SDcols=cols, by=stratum]
# #
# #   write.csv(m_loc_all,paste0(dir.list,m_loc,".csv"),row.names = FALSE)
# #
# # }
#
# ##Sum counts across populations for children under 1
# file.list <- paste0(dir.list, ind.locs.epp, '_under1_splits.csv')
# all.ind <- rbindlist(lapply(file.list , function(loc_i) {
#   print(loc_i)
#   sum.dt <- fread(loc_i)
#   return(sum.dt)
# }))
#
measures_child <- c("enn","lnn","x_388", 'x_389')
stratum <- c("year","run_num")
cols <- colnames(all.ind)[!colnames(all.ind) %in% stratum]
measures_child <- cols
options(datatable.optimize=1)
x <- all.ind[ ,lapply(.SD,as.numeric), .SDcols=cols]
all.ind <- cbind(x, all.ind[,.(  year, run_num)])
sum.ind <- all.ind[ ,lapply(.SD,sum), .SDcols=cols, by=stratum]
child_age <- age_groups[age_group_id %in% c(2,3,388,389)]
child_age[age_group_name == "Early Neonatal", age_group_name := "enn"]
child_age[age_group_name == "Late Neonatal", age_group_name := "lnn"]
child_age[age_group_name == "1-5 months", age_group_name := "x_388"]
child_age[age_group_name == "6-11 months", age_group_name := "x_389"]

# print("filling in missing locs for under 1s")
# # for(m_loc in missing.locs.child){
# #   m_loc1 <- loc.table[ihme_loc_id==m_loc,location_id]
# #   pop <- get_mort_outputs('population', 'estimate', location_id = m_loc1, age_group_ids = unique(child_age$age_group_id), year_ids = c(1970:2022), sex_ids = 3)
# #   pop_sa <-  get_mort_outputs('population single year', 'estimate', location_id = m_loc1, age_group_ids = unique(child_age$age_group_id),sex_ids = 3, year_ids = c(1970:2022))
# #   setnames(pop_sa, 'population', 'mean')
# #   pop <- rbind(pop[,.(year_id, location_id, ihme_loc_id, sex_id, age_group_id, mean, lower, upper)],
# #                pop_sa[,.(year_id, location_id, ihme_loc_id, sex_id, age_group_id, mean, lower, upper)])
# #   pop <- merge(pop, child_age, by = 'age_group_id')
# #
# #   m_loc2 <- loc.table[ihme_loc_id=="IND",location_id]
# #   pop_ind <- get_mort_outputs('population', 'estimate', location_id = m_loc2, age_group_ids = unique(child_age$age_group_id), sex_id = c(3), year_ids = c(1970:2022))
# #   pop_ind.sa <- get_mort_outputs('population single year', 'estimate', location_id = m_loc2, age_group_ids = unique(child_age$age_group_id), sex_id = c(3), year_ids = c(1970:2022))
# #   setnames(pop_ind.sa, 'population', 'mean')
# #   pop_ind <- rbind(pop_ind[,.(year_id, location_id, ihme_loc_id, sex_id, age_group_id, mean, lower, upper)],
# #                pop_ind.sa[,.(year_id, location_id, ihme_loc_id, sex_id, age_group_id, mean, lower, upper)])
# #   pop_ind <- merge(pop_ind, child_age, by = 'age_group_id')
# #
# #
# #   pop <- merge(pop,unique(child_age),by="age_group_id")
# #   pop_ind <- merge(pop_ind,unique(child_age),by="age_group_id")
# #   setnames(pop, 'mean', 'population')
# #   setnames(pop_ind, 'mean', 'population')
# #   all_pop <- merge(unique(pop[,.(year_id,age_group_name,population)]),unique(pop_ind[,.(year_id,age_group_name,population)]), by=c("age_group_name","year_id"))
# #   all_pop$pop.ratio <- all_pop$population.x/all_pop$population.y
# #
# #   setnames(all_pop ,c('year_id'), c('year'))
# #   sum.ind <- melt(sum.ind,id.var=c("year","run_num"))
# #   setnames(sum.ind,'variable','age_group_name')
# #   sum.ind <- merge(sum.ind,unique(all_pop[,.(year,age_group_name,pop.ratio)]),by=c('year','age_group_name'), allow.cartesian = T)
# #
# #   cols <- "value"
# #   x <- sum.ind[ ,lapply(.SD,as.numeric), .SDcols=cols]
# #   sum.ind <- cbind(x, sum.ind[,.(age_group_name,  year, run_num, pop.ratio)])
# #   m_loc_all <- unique(sum.ind[ ,lapply(.SD,"*",pop.ratio), .SDcols=cols, by=c('year','age_group_name','run_num')])
# #
# #   m_loc_all <- spread(unique(m_loc_all), key=c('age_group_name'), value="value")
# #
# #   write.csv(m_loc_all,paste0(dir.list,m_loc,"_under1_splits.csv"),row.names = FALSE)
# #
# # }
#
# ### Urban rural splitting ###
print("filling state locs")
# Fix zero
min <- min(prop.dt[prop > 0 , prop])
prop.dt[prop == 0, prop := min]
prop.dt[, prop := prop / sum(prop)]
missing.children <- setdiff(loc.table[grepl("IND", ihme_loc_id) & level == 5, ihme_loc_id], prop.dt$ihme_loc_id)
missing.parents <- unique(loc.table[location_id %in% loc.table[ihme_loc_id %in% missing.children, parent_id], ihme_loc_id])

state.locs <- c(loc.table[grepl("IND", ihme_loc_id) & level == 4 & epp == 1, ihme_loc_id],"IND_44538") #"IND_44538"-not run through EPP but filled in above


#

split_states <- function(state) {
  loc.id <- as.integer(strsplit(state, "_")[[1]][2])
  children <- loc.table[parent_id == loc.id, ihme_loc_id]
  #children <- children[!children %in% done]

  # set proportions - note no missing parents for now, else these could be age/sex specific (info available in PDFs above)
  # if(state %in% missing.parents) {
  #   props <- data.table()
  #   for(child in children) {
  #     child.name <- loc.table[ihme_loc_id == child, location_name]
  #     child.id <- loc.table[ihme_loc_id == child, location_id]
  #     if(grepl("Urban", child.name)) {
  #       cprop <- nat.urban06 * pop.dt[year == 2005 & location_id ==  child.id, population]
  #     } else {
  #       cprop <- nat.rural06 * pop.dt[year == 2005 & location_id ==  child.id, population]
  #     }
  #     props <- rbind(props, data.table(ihme_loc_id = child, prop = cprop))
  #   }
  # } else {
    props <- prop.dt[ihme_loc_id %in% children]     
  # }
  
  props[, prop := prop / sum(prop)]   
  
  
  
  #Create new file for each child location, merging across measures
  for(child in children) {
    ##Find parent state path and create rate measures where necessary
    print(child)
    dir <- dir.list
    path <- paste0(dir, state,".csv")
    state.dt <- fread(path)
    state.dt[,non_hiv_deaths := as.numeric(non_hiv_deaths)]

    stratum <-  c("age", "sex", "year","run_num")
    cols <- colnames(state.dt)[!colnames(state.dt) %in% stratum]
    measures <- cols
    child.result <- state.dt[,mget(stratum)]
    
    for(measure in measures) {
      print(measure)
      child.id <- loc.table[ihme_loc_id == child, location_id]
      measure <- as.character(measure)
      cols <- c(stratum,measure)
      state.dt.t <- state.dt[,mget(cols)]
      state.dt.t$run_num <- paste0("draw", state.dt.t$run_num )
      state.dt.t <- spread(unique(state.dt.t), run_num, get(measure))

      # max.draw <- max(state.dt$run_num)
      max.draw <- 10
      

      #times the state level counts by the child ART props for HIV positive outcomes and 
      #do we need child Population props for HIV negative outcomes?
      draw.cols <- paste0("draw",1:max.draw)
      child.dt <- copy(state.dt.t)
      if(any(colnames(child.dt) == 'draw50')){
        child.dt[,draw50:= NULL]
      }
      if(is.character(unlist(child.dt[,mget(draw.cols)][,1]))){
        x <- child.dt[ ,lapply(.SD,as.numeric), .SDcols=draw.cols]
        child.dt <- cbind(x, child.dt[,.(age,  year, sex)])
      }

      #if(measure %in% c("hiv_deaths","new_hiv","pop_art","hiv_births","birth_prev","pop_gt350" , "pop_200to350"  , "pop_lt200" )){
      child.dt <- child.dt[, (draw.cols) := lapply(.SD, '*',  props[ihme_loc_id == child, prop]), .SDcols = draw.cols][]
    # } else {
    #   pop_child <- fread(paste0(pops,"/india_splitting_locs/",child,".csv"))
    #   pop_parent <- fread(paste0(pops,state,".csv"))
    #   pop.ratios <- merge(unique(pop_child[,.(age_group_id,  year_id, sex_id, child_pop = population)]),
    #         unique(pop_parent[,.(age_group_id,  year_id, sex_id, parent_pop = population)]),by=c("age_group_id","year_id","sex_id"))
    #   pop.ratios  <- merge(pop.ratios,unique(get.age.groups),by="age_group_id")
    #   pop.ratios <- merge(pop.ratios,sex_groups,by="sex_id")
    #   setnames(pop.ratios ,c('year_id'), c('year'))
    #   pop.ratios$age <- as.integer(pop.ratios$age)
    #   pop.ratios[,pop.ratio := child_pop/parent_pop]
    #   child.dt <- merge(child.dt,pop.ratios[,.(year,sex,age,pop.ratio)], by=c('year','sex','age'))
    #   child.dt <- child.dt[, (draw.cols) := lapply(.SD, '*',  pop.ratio), .SDcols = draw.cols][]
    #   child.dt <- child.dt[,pop.ratio := NULL]
    # 
    # }
      child.dt <- melt(child.dt,id.vars = c("age","sex","year"))
      child.dt$variable <- as.integer(gsub("draw","", child.dt$variable))
      setnames(child.dt,c("variable","value"),c("run_num",measure))

      #Get counts for relevent measure  for child region
      child.result <- merge(child.result,child.dt)

    }

    write.csv(child.result, paste0(dir, child ,".csv"), row.names = F)
    
    ## Write out 15-49 incidence and prevalence to input to Spectrum
    spec.dt <- child.result[age %in% 15:49, .(age, sex, year, run_num, pop_neg, new_hiv, pop)]
    spec.dt <- spec.dt[,.(new_hiv = sum(new_hiv), pop_neg = sum(pop_neg), pop = sum(pop)), by = c('year', 'run_num')]
    spec.dt[, inc := ifelse(pop_neg == 0, 0, new_hiv/pop_neg)]
    spec.dt[, prev := ifelse(pop == 0, 0, (pop - pop_neg)/pop)]
    inc.dt <- spec.dt[,.(year, run_num, inc)]
    inc.dt[,inc:=inc*100]
    inc.dt <- dcast.data.table(inc.dt,year~run_num, value.var='inc')
    setnames(inc.dt, names(inc.dt)[!names(inc.dt) == 'year'], paste0('draw', names(inc.dt)[!names(inc.dt) == 'year']))
    inc.dt <- inc.dt[order(year),]
    if(!dir.exists(paste0(spec.inc.path))){
      dir.create(paste0(spec.inc.path))
    }
    write.csv(inc.dt, paste0(spec.inc.path, child, '.csv'), row.names = F)
    
    prev.dt <- spec.dt[,.(year, run_num, prev)]
    prev.dt[,prev:=prev*100]
    prev.dt <- dcast.data.table(prev.dt,year~run_num, value.var='prev')
    setnames(prev.dt, names(prev.dt)[!names(prev.dt) == 'year'], paste0('draw', names(prev.dt)[!names(prev.dt) == 'year']))
    prev.dt <- prev.dt[order(year),]
    if(!dir.exists(paste0(spec.prev.path))){
      dir.create(paste0(spec.prev.path))
    }
    write.csv(prev.dt, paste0(spec.prev.path, child, '.csv'), row.names = F)
    
    
    ##Under 1 splits
    path <- paste0(dir, state,"_under1_splits.csv")
    state.dt <- fread(path)
    measures_child <- c("enn","lnn","x_388", 'x_389')
    stratum <- c("year","run_num")
    child.result <- state.dt[,mget(stratum)]
    for(measure in measures_child) {
      child.id <- loc.table[ihme_loc_id == child, location_id]
      measure <- as.character(measure)
      cols <- c(stratum,measure)
      state.dt.t <- state.dt[,mget(cols)]
      state.dt.t$run_num <- paste0("draw", state.dt.t$run_num )
      state.dt.t <- spread(state.dt.t, run_num, get(measure))

      max.draw <- max(state.dt$run_num)

      #times the state level counts by the child ART props
      draw.cols <- paste0("draw",1:max.draw)
      child.dt <- copy(state.dt.t)
      child.dt <- child.dt[, (draw.cols) := lapply(.SD, '*',  props[ihme_loc_id == child, prop]), .SDcols = draw.cols][]
      child.dt <- melt(child.dt,id.vars = c("year"))
      child.dt$variable <- as.integer(gsub("draw","", child.dt$variable))
      setnames(child.dt,c("variable","value"),c("run_num",measure))

      #Get counts for relevent measure  for child region
      child.result <- merge(child.result,child.dt)

    }

    write.csv(child.result, paste0(dir, child ,"_under1_splits.csv"), row.names = F)
  }
  
}
ind.locs <- loc.table[grepl("IND",ihme_loc_id) & spectrum==1,ihme_loc_id]
ind.locs <- setdiff(ind.locs, c('IND_43880', 'IND_43877', 'IND_43911', 'IND_43910', 'IND_43875', 'IND_43874',
                                'IND_43909', 'IND_43872', 'IND_43873', 'IND_43882', 'IND_43881', 'IND_43883', 'IND_43884'))
state.locs <- c(loc.table[grepl("IND", ihme_loc_id) & level == 4 & epp == 1, ihme_loc_id],"IND_44538") #"IND_44538"-not run through EPP but filled in above
state.locs <- unique(loc.table[ihme_loc_id%in%ind.locs,parent_id])
state.locs <- loc.table[location_id %in% state.locs, ihme_loc_id]
mclapply(state.locs[1:10], split_states, mc.cores = 10)
mclapply(state.locs[11:20], split_states, mc.cores = 10)
mclapply(state.locs[21:28], split_states, mc.cores = 10)


### End
