library(mongolite)
library(tidyverse) # general utility & workflow functions
library(tidytext) # tidy implementation of NLP methods
library(tm) # general text mining functions, making document term matrixes
library(SnowballC) # for stemming
library(wordcloud)
library(RColorBrewer)
library(rphylotastic)

NLP_tokenizer <- function(x) {
  unlist(lapply(ngrams(words(x), 2:2), paste, collapse = "_"), use.names = FALSE)
}

buildDTM <- function(data, ngram = 1, stemming = FALSE, clean = TRUE) {
  corpus <- VCorpus(VectorSource(data))
  
  if (ngram == 1) {
    control <- list(
      stopwords = TRUE,
      wordLengths=c(3, 10),
      removePunctuation = T,
      removeNumbers = T,
      stemming = F,
      tolower = T,
      language <- 'en'
    )  
  } else {
    control <- list(
      tokenize = NLP_tokenizer,
      removePunctuation = FALSE,
      removeNumbers = FALSE, 
      stopwords = TRUE, 
      tolower = T, 
      stemming = F
    )
  }
  
  corpusDTM = DocumentTermMatrix(corpus,control = control)
  
  # convert the document term matrix to a tidytext corpus
  corpusDTM_tidy <- tidy(corpusDTM)
  
  if (stemming) {
    corpusDTM_tidy <- corpusDTM_tidy %>% 
      mutate(stem = wordStem(term)) 
      #%>%
      #mutate(stem = stemCompletion(stem, corpus))
  }
  
  if (!clean) {
    return (corpusDTM_tidy)
  }
  
  cleaned_documents <- corpusDTM_tidy %>%
    group_by(document) %>% 
    mutate(terms = toString(rep(term, count))) %>%
    select(document, terms) %>%
    unique()
  
  return(cleaned_documents)
}

m <- mongo(collection = 'interaction_records', db = 'dwca_interactions', url='mongodb://dwca_interaction:kurt1234@192.168.1.3:27017/?authSource=admin&readPreference=primary&ssl=false')

# ResourceRelationship
data <- m$find(query = '{"has_ResourceRelationship": 1}', fields = '{ "occurrenceID": 1,"scientificName": 1, "resourceID": 1, "resourceRelationshipID": 1, "relatedResourceID": 1, "relationshipOfResource": 1, "relationshipAccordingTo": 1, "relationshipEstablishedDate": 1, "relationshipRemarks": 1}')
head(data)
data <- data[str_length(data$relationshipOfResource) > 0,]

corpusDTM_tidy <- buildDTM(data$relationshipOfResource, ngram = 2, clean = FALSE, stemming = TRUE)
corpusDTM_tidy_sum <- corpusDTM_tidy %>%
  group_by(term) %>% 
  summarise(n = n())
set.seed(1234)
corpusDTM_tidy_sum
wordcloud(words = corpusDTM_tidy_sum$term, freq = corpusDTM_tidy_sum$n, min.freq = 2,
          max.words=200, random.order=FALSE, rot.per=0.35, 
          colors=brewer.pal(4, "RdBu"))

#remarks <- data[str_length(data$relationshipRemarks) > 0,]$relationshipRemarks
#length(remarks)
#associatedTaxa <- lapply(data$relationshipRemarks, text_get_scientific_names)


# Associated Occurrences
data <- m$find(query = '{"has_associatedOccurrences": 1}', fields = '{"occurrenceID": 1, "scientificName": 1, "associatedOccurrences": 1}')
data <- data[str_length(data$associatedOccurrences) > 0,]

corpusDTM_tidy <- buildDTM(data$associatedOccurrences, ngram = 1, stemming = T)
corpusDTM_tidy_sum <- corpusDTM_tidy %>%
  group_by(terms) %>% 
  summarise(n = n())
set.seed(1234)
corpusDTM_tidy_sum
wordcloud(words = corpusDTM_tidy_sum$terms, freq = corpusDTM_tidy_sum$n, min.freq = 2,
          max.words=200, random.order=FALSE, rot.per=0.35, 
          colors=brewer.pal(4, "RdBu"))



# Associated Taxa
data <- m$find(query = '{has_associatedTaxa: 1}', fields = '{occurrenceID: 1, scientificName: 1, associatedTaxa: 1}')

# Dynamic properties
data <- m$find(query = '{has_dynamicProperties: 1}', fields = '{occurrenceID: 1, scientificName: 1, dynamicProperties: 1}')

# Occurrence Remarks
data <- m$find(query = '{has_occurrenceRemarks: 1}', fields = '{occurrenceID: 1, scientificName: 1, occurrenceRamarks: 1}')


