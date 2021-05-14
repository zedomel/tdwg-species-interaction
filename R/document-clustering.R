# Loading the packages that will be used
list.of.packages <- c("tm", "dbscan", "proxy", "colorspace", 'SnowballC',  'wordcloud', 'topicmodels')
# (downloading and) requiring packages
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) 
  install.packages(new.packages)
for (p in list.of.packages) 
  require(p, character.only = TRUE)

dir = DirSource('./fulltext/', encoding = 'UTF-8')
corpus = Corpus(dir)
summary(corpus)

corpus <- tm::tm_map(corpus, function(x) iconv(x, to='ASCII', sub='')) 
removeURL <- function(x) gsub("http://([[:alnum:]|[:punct:]])+", '', x)
corpus <- tm::tm_map(corpus, content_transformer(removeURL))
corpus

ndocs <- length(corpus)
# ignore extremely rare words i.e. terms that appear in less then 1% of the documents
minTermFreq <- ndocs * 0.01
# ignore overly common words i.e. terms that appear in more than 50% of the documents
maxTermFreq <- ndocs * .5

dtm = DocumentTermMatrix(corpus,
                         control = list(
                           stopwords = TRUE,
                           wordLengths=c(4, 15),
                           removePunctuation = T,
                           removeNumbers = T,
                           stemming = T,
                           bounds = list(global = c(minTermFreq, maxTermFreq))
                         ))
tdm <- TermDocumentMatrix(corpus,
                          control = list(
                            stopwords = TRUE,
                            wordLengths=c(4, 15),
                            removePunctuation = T,
                            removeNumbers = T,
                            stemming = T,
                            bounds = list(global = c(minTermFreq, maxTermFreq))
                          ))

inspect(dtm)
inspect(tdm)

tdm.matrix = as.matrix(tdm)
dtm.matrix = as.matrix(dtm)

v <- sort(rowSums(tdm.matrix),decreasing=TRUE)
d <- data.frame(word = names(v),freq=v)
head(d, 10)

set.seed(1234)
wordcloud(words = d$word, freq = d$freq, min.freq = 1, max.words = 200, random.order = FALSE, rot.per=0.35, colors = brewer.pal(8, 'Dark2'))


barplot(d[1:10,]$freq, las = 2, names.arg = d[1:10,]$word,
        col ="lightblue", main ="Most frequent words",
        ylab = "Word frequencies")


distMatrix <- proxy::dist(dtm.matrix, method="cosine")
groups <- hclust(distMatrix,method="ward.D")
clustering <- cutree(groups, 5)
plot(groups, cex=0.9, hang=-1)

rect.hclust(groups, 5, border = "red", cluster = clustering)


clustering.dbscan <- dbscan::hdbscan(distMatrix, minPts = 10)

# Text representation
p_words <- colSums(dtm.matrix) / sum(dtm.matrix)
p_words
cluster_words <- lapply(unique(clustering), function(x){
  rows <- dtm.matrix[ , clustering == x]
  
  # for memory's sake, drop all words that don't appear in the cluster
  rows <- rows[ , colSums(rows) > 0 ]
  
  colSums(rows) / sum(rows) - p_words[ colnames(rows) ]
})
# create a summary table of the top 5 words defining each cluster
cluster_summary <- data.frame(cluster = unique(clustering),
                              size = as.numeric(table(clustering)),
                              top_words = sapply(cluster_words, function(d){
                                paste(
                                  names(d)[ order(d, decreasing = TRUE) ][ 1:5 ], 
                                  collapse = ", ")
                              }),
                              stringsAsFactors = FALSE)
cluster_summary
wordcloud(words = names(cluster_words[[ 5 ]]), 
          freq = cluster_words[[ 5 ]], 
          max.words = 50, 
          random.order = FALSE, 
          colors = c("red", "yellow", "blue"),
          main = "Top words in cluster 100")




# Abstracts
data <- read.csv('python/zotero_metadata.csv', stringsAsFactors = FALSE)
summary(data)

corpus <- Corpus(VectorSource(data$abstractNote))
dtm <- DocumentTermMatrix(corpus,
                          control = list(
                            stopwords = TRUE,
                            wordLengths=c(4, 15),
                            removePunctuation = T,
                            removeNumbers = T,
                            stemming = T,
                            bounds = list(global = c(minTermFreq, maxTermFreq))
                          ))
