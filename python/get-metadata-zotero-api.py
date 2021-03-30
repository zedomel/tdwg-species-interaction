from pyzotero import zotero
from requests.exceptions import HTTPError

import csv

library_id = 2312718
library_type = 'group'
api_key = '0lwTcCba9FPbgUWL2kqG8mBZ'
#collection_id = 'YTEKHT24'

metadata_keys = {
    'key': 'key',
    'itemType': 'item_type',
    'title': 'pub_title',
    'abstractNote': 'pub_abstract',
    'publicationTitle': 'pub_journal',
    'date': 'pub_year',
    'DOI': 'pub_doi'
}

zot = zotero.Zotero(library_id, library_type, api_key)
with open('interaction_datasets.csv', 'r') as datasetfile, open('interaction_datasets_zotero.csv', 'w') as csvfile:
    reader = csv.DictReader(datasetfile)
    writer = csv.DictWriter(csvfile, fieldnames=(['key', 'item_type'] + reader.fieldnames))
    writer.writeheader()

    for row in reader:
        if row['pub_title'] :
            items = zot.items(q=row['pub_title'],itemType='-attachment', limit=1)
            if items:
                item = items[0]['data']
                for key, col in metadata_keys.items():
                    if key in item:
                        if key == 'DOI':
                            row[col] = 'https://doi.org/' + item[key]
                        else :
                            row[col] = item[key]

                if 'creators' in item:
                    row['pub_authors'] = ';'.join(["%s %s" % (a['lastName'], a['firstName']) for a in item['creators'] if 'lastName' in a and 'firstName' in a])

                if 'tags' in item:
                    row['pub_keywords_subject'] = ';'.join([k['tag'] for k in item['tags']])

                # Get Full-text
                #
                attachments = zot.children(item['key'])
                if attachments:
                    for attach in attachments:
                        if attach['data']['contentType'] == 'application/pdf' :
                            try:
                                fulltext = zot.fulltext_item(attach['key'])
                                with open(f'./fulltext/{key}.txt', "w") as text_file:
                                    text_file.write(fulltext['content'])
                            except HTTPError as e:
                                print(f'FullText: {key}')

        writer.writerow(row)

