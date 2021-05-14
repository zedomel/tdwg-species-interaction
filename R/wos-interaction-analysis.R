library(bibliometrix)
library(data.table)
library(igraph)
library(ggpubr)
library(dplyr)
library(tidyverse)
library(tidytext)
library(wordcloud2)
library(forcats)
library(textstem)

categories <- c(
  'Ecology',
  'Entomology',
  'Biodiversity Conservation',
  'Biology',
  'Fisheries',
  'Microbiology',
  'Mycology',
  'Ornithology',
  'Infectious Diseases',
  'Parasitology',
  'Virology',
  'Ecology',
  'Zoology',
  'Marine & Freshwater Biology'
)
categories <- c('Ecology')
year <- c(1970,2020)
topics <- c('species interaction$', 'biotic interaction$', 'ecological interaction$', 'inter(-)specific interaction$', 'biological interaction$', 'community interaction$')

query <- sprintf('TS=(%s) AND PY=(%s) AND WC=(%s) AND DT=Article', 
                 paste(dQuote(topics, q= F), collapse = ' OR '),
                 paste(year, collapse = '-'), 
                 paste(categories, collapse = ' OR '))
query

files <- list.files('articles/', full.names = T)
files

m <- lapply(files, function(file) {
  convert2df(file = file, dbsource = 'wos', format = 'endnote')
  }
)

# Merge articles
m.all <- do.call(mergeDbSources, m)

# Extract matching topics
topics_matrix <- matrix(F,nrow = nrow(m.all), ncol=length(topics)+1)
fields <- c('TI', 'AB', 'DE', 'ID')

for (i in 1:length(topics)) {
  topic <- str_replace(topics[i], '\\$', '.?')
  topic
  for (f in fields){
    matches <- sapply(m.all[,f], function(x) {
      m <- grep(pattern = topic, x, ignore.case = T)
      if (length(m) > 0 && m > 0) {
        return(T)
      }
      return(F)
    })
    topics_matrix[, i] <- topics_matrix[,i] | as.numeric(matches)
  }
}
topics_matrix <- 1*topics_matrix
# Put publication year into the topics matrix
topics_matrix[,7] <- m.all$PY
topics_matrix

topics.df <- as.data.frame(topics_matrix)
names(topics.df) <- c(str_replace_all(topics, '\\$', ''), 'year')

# Group by year and sum total of publications
topics.year <- topics.df %>%
  filter(year < 2021) %>%
  group_by(year) %>%
  summarise(across(everything(), sum))
topics.year

# Transform topics by year into tidy for plot
df <- topics.year %>%
  select(year,`species interaction`, `biotic interaction`, `ecological interaction`, `inter(-)specific interaction`, `biological interaction`, `community interaction`) %>%
  gather(key='variable', value='value', -year)
head(df)
ggplot(df, aes(x=year, y = value)) +
  geom_line(aes(color= variable)) +
  scale_color_discrete(name = 'Term') +
  ggtitle('Number of publications including the term “species interaction” and other similar terms throughout the years') +
  xlab('Year') +
  ylab('Number of publications')


NetMatrix <- biblioNetwork(m.all, analysis = "co-occurrences", network = "keywords", sep = ";")
net=networkPlot(NetMatrix, normalize="association", weighted=T, n = 10, Title = "Keyword Co-occurrences", type = "fruchterman", size=T,edgesize = 5,labelsize=0.7)


CS <- conceptualStructure(m.all,field="ID", method="CA", minDegree=4, clust=5, stemming=FALSE, labelsize=10, documents=10)
