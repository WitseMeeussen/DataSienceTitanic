library(tidyverse)
# data wrangling

library(tidyverse)
library(forcats)
library(stringr)
library(caTools)

# data assessment/visualizations

library(DT)
library(data.table)
library(pander)
library(ggplot2)
library(scales)
library(grid)
library(gridExtra)
library(corrplot)
library(VIM) 
library(knitr)
library(vcd)
library(caret)

# model

library(xgboost)
library(MLmetrics)
library('randomForest') 
library('rpart')
library('rpart.plot')
library('car')
library('e1071')
library(vcd)
library(ROCR)
library(pROC)
library(VIM)
library(glmnet) 


train <- read_csv('train.csv')
test <- read_csv('test.csv')

train$set <- "train"

test$set  <- "test"

test$Survived <- NA

full  <- bind_rows(train, test)
# check data

str(full)



# dataset dimensions

dim(full)



# Unique values per column

lapply(full, function(x) length(unique(x))) 



#Check for Missing values



missing_values <- full %>% summarize_all(funs(sum(is.na(.))/n()))



missing_values <- gather(missing_values, key="feature", value="missing_pct")

missing_values %>% 
  
  ggplot(aes(x=reorder(feature,-missing_pct),y=missing_pct)) +
  
  geom_bar(stat="identity",fill="red")+
  
  coord_flip()+theme_bw()
#___________________________________________________________________________________________
#Mutating the data

#Replace missing Age cells with the mean Age of all passengers on the Titanic.

full <- full %>%
  
  mutate(
    
    Age = ifelse(is.na(Age), mean(full$Age, na.rm=TRUE), Age),
    
    `Age Group` = case_when(Age < 13 ~ "Age.0012", 
                            
                            Age >= 13 & Age < 18 ~ "Age.1317",
                            
                            Age >= 18 & Age < 60 ~ "Age.1859",
                            
                            Age >= 60 ~ "Age.60Ov"))

#Use the most common code to replace NAs in the Embarked feature.

full$Embarked <- replace(full$Embarked, which(is.na(full$Embarked)), 'S')


names <- full$Name

title <-  gsub("^.*, (.*?)\\..*$", "\\1", names)

full$title <- title

table(title)

#Change the titles

full$title[full$title == 'Mlle']        <- 'Miss' 

full$title[full$title == 'Ms']          <- 'Miss'

full$title[full$title == 'Mme']         <- 'Mrs' 

full$title[full$title == 'Lady']          <- 'Miss'

full$title[full$title == 'Dona']          <- 'Miss'


full$title[full$title == 'Capt']        <- 'Officer' 

full$title[full$title == 'Col']        <- 'Officer' 

full$title[full$title == 'Major']   <- 'Officer'

full$title[full$title == 'Dr']   <- 'Officer'

full$title[full$title == 'Rev']   <- 'Officer'

full$title[full$title == 'Don']   <- 'Officer'

full$title[full$title == 'Sir']   <- 'Officer'

full$title[full$title == 'the Countess']   <- 'Officer'

full$title[full$title == 'Jonkheer']   <- 'Officer'


# categorizing families

full$FamilySize <-full$SibSp + full$Parch + 1 

full$FamilySized[full$FamilySize == 1] <- 'Single' 

full$FamilySized[full$FamilySize < 5 & full$FamilySize >= 2] <- 'Small' 

full$FamilySized[full$FamilySize >= 5] <- 'Big' 

full$FamilySized=as.factor(full$FamilySized)


##Engineer features based on all the passengers with the same ticket

ticket.unique <- rep(0, nrow(full))

tickets <- unique(full$Ticket)

for (i in 1:length(tickets)) {
  
  current.ticket <- tickets[i]
  
  party.indexes <- which(full$Ticket == current.ticket)
  
  for (k in 1:length(party.indexes)) {
    
    ticket.unique[party.indexes[k]] <- length(party.indexes)
    
  }
  
}

full$ticket.unique <- ticket.unique

full$ticket.size[full$ticket.unique == 1]   <- 'Single'

full$ticket.size[full$ticket.unique < 5 & full$ticket.unique>= 2]   <- 'Small'

full$ticket.size[full$ticket.unique >= 5]   <- 'Big'

#__________________________________________________________________________________________
#SURVIVAL

full <- full %>%
  
  mutate(Survived = case_when(Survived==1 ~ "Yes", 
                              
                              Survived==0 ~ "No"))



crude_summary <- full %>%
  
  filter(set=="train") %>%
  
  select(PassengerId, Survived) %>%
  
  group_by(Survived) %>%
  
  summarise(n = n()) %>%
  
  mutate(freq = n / sum(n))



crude_survrate <- crude_summary$freq[crude_summary$Survived=="Yes"]



kable(crude_summary, caption="2x2 Contingency Table on Survival.", format="markdown")

#__________________________________________________________________________________________
# PLOTS
# SURVIVAL BASED ON CLASS
ggplot(full %>% filter(set=="train"), aes(Pclass, fill=Survived)) +
  
  geom_bar(position = "fill") +
  
  scale_fill_brewer(palette="Set1") +
  
  scale_y_continuous(labels=percent) +
  
  ylab("Survival Rate") +
  
  geom_hline(yintercept=crude_survrate, col="white", lty=2, size=2) +
  
  ggtitle("Survival Rate by Class") + 
  
  theme_minimal()


# SURVIVAL BASED ON TITLE
ggplot(full %>% filter(set=="train") %>% na.omit, aes(title, fill=Survived)) +
  
  geom_bar(position="stack") +
  
  scale_fill_brewer(palette="Set1") +
  
  scale_y_continuous(labels=comma) +
  
  ylab("Passengers") +
  
  ggtitle("Survived by Title") + 
  
  theme_minimal() +
  
  theme(axis.text.x = element_text(angle = 90, hjust = 1))

#SURVIVAL BY SEX

ggplot(full %>% filter(set=="train"), aes(Sex, fill=Survived)) +
  
  geom_bar(position = "stack") +
  
  scale_fill_brewer(palette="Set1") +
  
  scale_y_continuous(labels=percent) +
  
  ylab("Survival Rate") +
  
  geom_hline(yintercept=crude_survrate, col="white", lty=2, size=2) +
  
  ggtitle("Survival Rate by Sex") + 
  
  theme_minimal()
