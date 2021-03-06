# Objective 1: Design an R function for policy analysis
# Objective 2: Analyze data on opioid-related deaths in New York State between 2003 and 2017

#################################################################################################################

# Step 1: Import and clean datasets

# Step 1a: Create data frame 1 using opioid related deaths dataset
#dataset 1 description - New York State Vital Statistics: Opioid-Related Deaths by County: Beginning 2003
#dataset 1 selected metadata (from download page):
#modified: 2019-09-30
#release date: 2017-11-16

#import opioid data (dataset 1 - opioid deaths 2003-present)
opd <- tryCatch({
  read.csv("https://health.data.ny.gov/api/views/sn5m-dv52/rows.csv?accessType=DOWNLOAD", stringsAsFactors = FALSE)
}, error = function(e){
 read.csv("https://github.com/miftachowdhury/R-NYS_Opioid_Deaths/raw/master/Data/Vital_Statistics__Opioid-Related_Deaths_by_County__Beginning_2003.csv", stringsAsFactors = FALSE) 
})

#check opioid data
str(opd)
#dataset contains 930 observations of 3 variables

summary(opd)
#year min=2003;  year max=2017

table(opd$Year)
#for each of the 15 year values, there are 62 observations (counties)

range(table(opd$County))
#for each of the 62 county values, there are 15 observations (years)

sum(is.na(opd))
#no missing data

opd[opd$County=="St Lawrence", "County"] <- "St. Lawrence"
#match spelling in dataset 2

#print names of 62 counties
unique(opd$County)

#################################################################################################################

# Step 1b: Create data frame 2 using population data
#dataset 2 description - Annual Population Estimates for New York State and Counties: Beginning 1970
#dataset 2 selected metadata:
#data last updated: April 19, 2019
#date created: August 14, 2014

#import population data (dataset 2 - resident population of New York State and counties beginning 1970)
pop <- tryCatch({
  read.csv("https://data.ny.gov/api/views/krt9-ym2k/rows.csv?accessType=DOWNLOAD", stringsAsFactors = FALSE)
}, error = function(e){
 read.csv("https://github.com/miftachowdhury/R-NYS_Opioid_Deaths/raw/master/Data/Annual_Population_Estimates_for_New_York_State_and_Counties__Beginning_1970.csv", stringsAsFactors = FALSE) 
})

#check population data
str(pop)
summary(pop)
#dataset contains 3,402 observations of 5 variables
#year min=1970; year max=2018

#just keep observations from 2003 to 2017 inclusive (to match opd data frame)
pop <- subset(pop, Year %in% 2003:2017)
range(pop$Year)
str(pop)
#1,008  observations of 5 variables

length(unique(pop$Geography))
#63 geographies

length(unique(pop$Year))
#15 years

#questions:
#Q1) why 63 geographies instead of 62?
#Q2) why 1,008 observations (=63x16) when # unique years = 15?

unique(pop$Geography)
#A1) because the 63rd geography is New York State; keep this for later use

table(pop$Year)
#A2) each county has two observations for 2010; one is the official decennial census count
#but should drop the census count 2010 data for consistency

table(pop$Program.Type)
#want to drop Program Type="Census Base Population"

pop<-subset(pop, Program.Type != "Census Base Population")
nrow(pop)
#dropped observations where Program Type= "Census Base Population"
#now we have a total of 945 observations
  #930 observations (62 counties x 15 years) correspond to records in opioid dataset
  #15 observations are New York State totals per year

#drop the " County" substring from the data because it is extraneous and to prep for merge
i<-1
for (i in 1:nrow(pop)){
  if (pop[i,2]!="New York State"){
    pop[i,2] <- substr(pop[i,2], 1, nchar(pop[i,2])-7)
    i<-i+1
  }
}

#check that " County" substring has been removed
unique(pop$Geography)

#rename the "Geography" column to "County" to prep for merge
names(pop)[names(pop)=="Geography"] <- "County"

#check that "Geography" has been renamed to "County"
names(pop)

sum(is.na(pop))
#no missing data

#################################################################################################################

# Step 2: Merge data frame 1(opd) and data frame 2(pop) on County, to create a new merged data frame

#merge the data frames
opd2 <- merge(opd, pop, all=TRUE, sort=TRUE)
str(opd2)

#################################################################################################################

# Step 3: Create new variables in the new merged data frame

#create new variable Death.Rate to store number of opioid-related deaths per million people
  y<-2003
  for (y in 2003:2017){
    opd2$Opioid.Poisoning.Deaths[which(opd2$County=="New York State" & opd2$Year==y)] <- sum(opd2$Opioid.Poisoning.Deaths[which(opd2$County!="New York State" & opd2$Year==y)])
  }
  #calculated total opioid-related deaths in NYS per year (which was not included in the original opd dataset)
  
  opd2$PopMillion <- opd2$Population/1000000
  opd2$Death.Rate <- opd2$Opioid.Poisoning.Deaths/opd2$PopMillion
  #calculated opioid-related death rate per million people

#create new variables Pct.Deaths and Pct.Pop to store a county's share of statewide deaths and share of statewide population
  y<-2003
  i<-1
  for (y in 2003:2017){
    for (i in 1:nrow(opd2)){
      ifelse(opd2[i,1]==y, opd2$Total.Deaths[i] <- opd2$Opioid.Poisoning.Deaths[which(opd2$County=="New York State" & opd2$Year==y)], opd2$Total.Deaths<-opd2$Total.Deaths)
      ifelse(opd2[i,1]==y, opd2$Total.Pop[i] <- opd2$Population[which(opd2$County=="New York State" & opd2$Year==y)], opd2$Total.Pop<-opd2$Total.Pop)
    }
    y<-y+1
  }
  
  opd2$Pct.Deaths<-opd2$Opioid.Poisoning.Deaths*100/opd2$Total.Deaths
  opd2$Pct.Pop <- opd2$Population*100/opd2$Total.Pop


#################################################################################################################

# Step 4: Create the function

#Goal of the function is to allow a user to input the name of a New York State county, as well as two different years between 2003 and 2017 and for both county and state return: 
# 1) Rates of opioid-related deaths per million people for each of the two years
# 2) The percent change between the two years, including whether the rate increased or decreased

# Additionally, I would also like to return for each of the two years:
# 3) Percentage of total statewide deaths accounted for by the county
# 4) Percentage of total statewide population accounted for by the county

op_deaths <- function(data, county, year1, year2){
  attach(data)
  #year 1
  opd1C <- subset(data, County==county & Year==year1)
  opd1S <- subset(data, County=="New York State" & Year==year1)
  
  #year 2
  opd2C <- subset(data, County==county & Year==year2)
  opd2S <- subset(data, County=="New York State" & Year==year2)
  
  #percent change
  pct.chgC <- round((opd2C$Death.Rate - opd1C$Death.Rate)*100/opd1C$Death.Rate, 1)
  pct.chgS <- round((opd2S$Death.Rate - opd1S$Death.Rate)*100/opd1S$Death.Rate, 1)
  chg.typeC <- ifelse(pct.chgC>=0, "increased by ", "decreased by ")
  chg.typeS <- ifelse(pct.chgS>=0, "increased by ", "decreased by ")
  
  #year 1 rates per million people
  y1rateC <- round(opd1C$Death.Rate,1)
  y1rateS <- round(opd1S$Death.Rate,1)
  
  #year 1 percentages 
  y1pct.deaths <- round(opd1C$Pct.Deaths,1)
  y1pct.pop <- round(opd1C$Pct.Pop,1)
  
  #year 2 rates per million people
  y2rateC <- round(opd2C$Death.Rate,1)
  y2rateS <- round(opd2S$Death.Rate,1)
  
  #year 2 percentages
  y2pct.deaths <- round(opd2C$Pct.Deaths,1)
  y2pct.pop <- round(opd2C$Pct.Pop,1)
  
  
  detach(data)
  
  cat("In",year1,":\n", 
      "There were",y1rateC,"opioid-related deaths per million people in",county,"County.\n", 
      "There were",y1rateS,"opioid-related deaths per million people in New York State.", "\n\n", 
      "In",year2,":\n",
      "There were",y2rateC,"opioid-related deaths per million people in",county,"County.\n", 
      "There were",y2rateS,"opioid-related deaths per million people in New York State.","\n\n",
      "In",year1,",",county,"County accounted for",y1pct.deaths,"percent of opioid-related deaths in New York State and",y1pct.pop,"percent of the state's total population.\n", 
      "In",year2,",",county,"County accounted for",y2pct.deaths,"percent of opioid-related deaths in New York State and",y2pct.pop,"percent of the state's total population.\n\n", 
      "From",year1,"to",year2,"the opioid-related death rate",chg.typeC,pct.chgC,"percent in",county, "County.\n",
      "From",year1,"to",year2,"the opioid-related death rate",chg.typeS, pct.chgS,"percent in New York State.")
}

op_deaths(opd2, "Kings", 2003, 2008)
