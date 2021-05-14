library(rcrossref)
library(crminer)
library(stringr)
library(tidyr)
library(dplyr)
library(xml2)

crm_cache$cache_path_set(full_path = './crminer_cache')

all_data <- read.csv('interaction_datasets.csv');

# Get DOI's
dois <- sapply(all_data$pub_doi, str_match, 'https://doi.org/(.*)$')[2,]
dois

# Not NA
ind <- which(!is.na(dois))

# Remove NA
curr_dois <- dois[ind]

# Create new columns
all_data$cr_title <- NA
all_data$cr_pub_date <- NA
all_data$cr_authors <- NA

n <- length(curr_dois)
n
for (i in 1:n) {
  # Fetch Metadata from CrossRef API 
  meta <- try(cr_works(dois = curr_dois[i]),silent = F)
  if (!inherits(meta,'try-error')) {
    metadata <- meta$data
  
    all_data[i,]$cr_title <- metadata$title
    all_data[i,]$cr_pub_date <- metadata$published.print
    all_data[i,]$cr_authors <- unlist(metadata$author[[1]] %>%
      unite('author', family, given, sep = ',') %>%
      summarise_all(~(paste(., collapse = ";"))) %>%
      select(author))
  
    links <- crm_links(metadata$doi)
    t <- NULL
  
    if ('pdf' %in% names(links)) {
      r <- try(crm_pdf(links), silent = F)
      if (!inherits(r, 'try-error')) {
        t <- paste(r$text, collapse = '\n')
      }
    } 
    if (is.null(t) && 'xml' %in% names(links)) {
      r <- try(crm_xml(links), silent = F)
      if (!inherits(r, 'try-error')) {
        t <- xml_text(r) 
      }
    }
    if (is.null(t) && 'html' %in% names(links)) {
      r <- try(crm_text(links, type = 'html'), silent = F)
      if (!inherits(r, 'try-error')) {
        t <- xml_text(r) 
      }
    }
    if (is.null(t) && 'plain' %in% names(links)) {
      r <- try(crm_text(links, type = 'plain'), silent = F)
      if (!inherits(r, 'try-error')) {
        t <- r
      }
    } 
    if (is.null(t)) {
      for(url in links) {
        r <- try(crm_pdf(url, overwrite_unspecified = TRUE, read = T), silent = F)
        if (!inherits(r, 'try-error')) {
          e <- crm_extract(r)
          t <- paste(r$text, collapse = '\n')
          break
        }
      }
    }
  
    if (!is.null(t)) {
      conn <- file(paste0('./fulltext/', str_replace_all(metadata$doi, '/', '_'), '.txt'), 'w')
      writeLines(t, conn)
      close(conn)
    }
  }
}

write.csv(all_data, file = 'interaction_datasets_crossref.csv', sep = ',', row.names = F)


# Create a table to map columns to DwC terms
n <- nrow(all_data)
col.mapping <- data.frame(index = NA, col_name = NA)
for(i in 1:n) {
  row <- all_data[i,]
  col_names <- str_split(row$columns_keys, ';')
  columns <- data.frame(index = rep(i, length(col_names)), col_name = col_names)
  col.mapping <- rbind(col.mapping, columns)
}

col.mapping