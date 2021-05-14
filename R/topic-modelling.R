# read in the libraries we're going to use
library(tidyverse) # general utility & workflow functions
library(tidytext) # tidy implimentation of NLP methods
library(topicmodels) # for LDA topic modelling 
library(tm) # general text mining functions, making document term matrixes
library(SnowballC) # for stemming
library(wordcloud)
library(RColorBrewer)

# Unsupervised
# of topics, using LDA
top_terms_by_topic_LDA <- function(input_text, # should be a columm from a dataframe
                                   number_of_topics = 4) # number of topics (4 by default)
{    
  # create a corpus (type of object expected by tm) and document term matrix
  Corpus <- Corpus(VectorSource(input_text)) # make a corpus object
  DTM <- DocumentTermMatrix(Corpus) # get the count of words/document
  
  # remove any empty rows in our document term matrix (if there are any 
  # we'll get an error when we try to run our LDA)
  unique_indexes <- unique(DTM$i) # get the index of each unique value
  DTM <- DTM[unique_indexes,] # get a subset of only those indexes
  
  # preform LDA & get the words/topic in a tidy text format
  lda <- LDA(DTM, k = number_of_topics, control = list(seed = 1234))
  #lda <- LDA(DTM, k = number_of_topics, control = list(seed = 1234, alpha=0.5, iter=2000, thin=1, burnin=500), method = 'Gibbs')
  return(lda)
}

getTopicTerms <- function(lda, plot = T) {
  topics <- tidy(lda, matrix = "beta")
  
  # get the top ten terms for each topic
  top_terms <- topics  %>% # take the topics data frame and..
    group_by(topic) %>% # treat each topic as a different group
    top_n(10, beta) %>% # get the top 10 most informative words
    ungroup() %>% # ungroup
    arrange(topic, -beta) # arrange words in descending informativeness
  
  # if the user asks for a plot (TRUE by default)
  if(plot == T){
    # plot the top ten terms for each topic in order
    top_terms %>% # take the top terms
      mutate(term = reorder(term, beta)) %>% # sort terms by beta value 
      ggplot(aes(term, beta, fill = factor(topic))) + # plot beta by theme
      geom_col(show.legend = FALSE) + # as a bar plot
      facet_wrap(~ topic, scales = "free") + # which each topic in a seperate plot
      labs(x = NULL, y = "Beta") + # no x label, change y label 
      coord_flip() # turn bars sideways
  }else{ 
    # if the user does not request a plot
    # return a list of sorted terms instead
    return(top_terms)
  }
}
removeURL <- function(x) gsub("http://([[:alnum:]|[:punct:]])+", '', x)

datasets <- read.csv('interaction_datasets_final.csv', stringsAsFactors = F)

# Only datasets with abstract
ind <- !stringi::stri_isempty(datasets$pub_abstract)
datasets <- datasets[ind,]

# Clean data
# create a document term matrix to clean
corpus <- Corpus(VectorSource(datasets$pub_abstract)) 

corpus <- tm::tm_map(corpus, function(x) iconv(x, to='ASCII', sub='')) 
corpus <- tm::tm_map(corpus, content_transformer(removeURL))
corpus <- tm::tm_map(corpus, stripWhitespace)

ndocs <- length(corpus)
ndocs
# ignore extremely rare words i.e. terms that appear in less then 1% of the documents
minTermFreq <- ndocs * 0.01
# ignore overly common words i.e. terms that appear in more than 50% of the documents
maxTermFreq <- ndocs * .5

corpusDTM = DocumentTermMatrix(corpus,
                         control = list(
                           stopwords = TRUE,
                           wordLengths=c(4, 15),
                           removePunctuation = T,
                           removeNumbers = T,
                           stemming = F,
                           tolower = T,
                           language <- 'en',
                           bounds = list(global = c(minTermFreq, maxTermFreq))
                         ))

# convert the document term matrix to a tidytext corpus
corpusDTM_tidy <- tidy(corpusDTM)

# I'm going to add my own custom stop words that I don't think will be
# very informative in hotel reviews
custom_stop_words <- tibble(word = c("interaction", "biotic","species", 'individual', 'including','names', "interactions","data", "dataset","database", "research", "information","associated"))

# remove stopwords
corpusDTM_tidy <- corpusDTM_tidy %>% # take our tidy dtm and...
  anti_join(custom_stop_words, by = c("term" = "word")) # remove my custom stopwords

corpusDTM_tidy <- corpusDTM_tidy %>% 
  mutate(stem = wordStem(term)) %>%
  mutate(stem = stemCompletion(stem, corpus))

# reconstruct our documents
cleaned_documents <- corpusDTM_tidy %>%
  group_by(document) %>% 
  mutate(terms = toString(rep(stem, count))) %>%
  select(document, terms) %>%
  unique()

# reconstruct cleaned documents (so that each word shows up the correct number of times)
#cleaned_documents <- corpusDTM_tidy %>%
#  group_by(document) %>% 
#  mutate(terms = toString(rep(term, count))) %>%
#  select(document, terms) %>%
#  unique()

# check out what the cleaned documents look like (should just be a bunch of content words)
# in alphabetic order
head(cleaned_documents)

maxK <- 20
k_list <- seq(2,maxK, by = 1)
model_list <- list()
mod_log_lik = numeric(maxK)
mod_perplexity = numeric(maxK)
for (k in k_list) {
  # plot top ten terms in the hotel reviews by topic
  model <- top_terms_by_topic_LDA(cleaned_documents$terms, number_of_topics = k)
  mod_log_lik[k] <- logLik(model)
  mod_perplexity[k] <- perplexity(model)
  model_list[[k]] <- model
}

mod_log_lik
mod_perplexity
plot(k_list,mod_perplexity[2:maxK],type='b', xlab = 'Num. of topics', ylab = 'Perplexity', main='Model Perplexity by number of topics')
mod_perplexity[1] <- 999
bestModelInd <- which(mod_perplexity== min(mod_perplexity))
bestModelInd
bestModelInd <- 4
diff = numeric(length = length(mod_perplexity))
for (i in 2:length(mod_perplexity)) {
  diff[i] = mod_perplexity[i-1] - mod_perplexity[i]  
}
diff
top_terms <- getTopicTerms(model_list[[bestModelInd]], plot = F)
getTopicTerms(model_list[[bestModelInd]])

# Word Cloud for each topic
p = par()
par(mfrow=(c(bestModelInd/2,bestModelInd/2)))
for (i in unique(top_terms$topic)) {
  png(paste('./plots/wc-', i, '.png', sep = ''))
  wordcloud(words = top_terms[top_terms$topic == i,]$term, freq = top_terms[top_terms$topic == i,]$beta, max.words = 50, colors = RColorBrewer::brewer.pal(10, 'RdBu'), main = "Top words in cluster 50")
  dev.off()
}
par(p)


