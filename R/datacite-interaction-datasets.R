library(rdatacite)
library(tidyverse)

year <- c(1970,2022)
topics <- data.frame(topic=dQuote(c('species interaction?', 'biotic interaction*', 'ecological interaction*', 'interspecific interaction*', 'inter-specific interaction*', 'biological interaction*', 'community interaction*'), q=F))
fields <- data.frame(field=c('descriptions.description', 'titles.title'))


query <- unite(crossing(fields, topics), term, c(field,topic), sep = ':')
query <- sprintf('%s', str_flatten(query$term, ' OR '))
query

x <- dc_dois(query = query, resource_type_id = 'Dataset', limit = 1000)
x$data$attributes[1,]

repositories <- x$data$attributes %>%
  dplyr::select(publisher, url)
repositories$url[1:10]

