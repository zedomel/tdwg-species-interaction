import csv
import feedparser
import requests
import re

from pygbif import registry
from dateutil import parser
from urllib import parse


DRYAD_URL = 'https://datadryad.org/api/v2'
DOI_HANDLE_URL = 'https://doi.org/api/handles/'

def get_dwca_endpoints_from_rss(row):
    d = feedparser.parse(row['repo_url'])
    rows = []
    if len(d.entries) > 0:
        for item in d.entries:
            new_row = row.copy()
            new_row['format'] = 'ZIP'
            new_row['structure_schema'] = 'DWCA'
            new_row['dataset_title'] = item['title']
            new_row['dataset_url'] = item['link'].replace('resource', 'archive.do')
            new_row['dataset_year'] = parser.parse(item['published']).strftime('%Y')
            rows.append(new_row)

    return rows


def get_dwca_endpoints_from_gbif(row):
    m = re.search('https://doi.org/(.*)', row['repo_url'], re.IGNORECASE)
    if m :
        doi = m.group(1)
        r = requests.get(DOI_HANDLE_URL + doi)
        if r.status_code == 200 :
            body = r.json()
            for value in body['values']:
                if value['type'] == 'URL':
                    gbifUrl = value['data']['value']
                    datasetId = gbifUrl.split("/")[-1]
                    metadata = get_gbif_metadata(datasetId)
                    if metadata != None:
                        row['dataset_title'] = metadata['title']
                        row['dataset_description'] = metadata['description']
                        row['dataset_year'] = parser.parse(metadata['modified']).strftime('%Y')
                        row['dataset_keywords'] = ";".join([t.value for t in metadata['tags']])
                        for endpoint in metadata['endpoints']:
                            if endpoint['type'] == 'DWC_ARCHIVE':
                                row['dataset_url'] = endpoint['url']
                                break


def get_gbif_metadata(datasetId):
    try:
        return registry.datasets(uuid=datasetId, data='all')
    except Exception as e:
        print(f'Dataset not found {datasetId}')
        return None


def get_dryad_metadata(row):
    # https://doi.org/10.1098/rspb.2014.2925
    m = re.search('https://doi.org/(.*)', row['repo_url'], re.IGNORECASE)
    if m:
        doi = parse.quote_plus(m.group(1))
        r = requests.get(DRYAD_URL + f'/dataset/{doi}')
        if r.status_code == 200:
            body = r.json()
            row['dataset_title'] = body['title']
            row['dataset_description'] = body['abstract']
            row['dataset_keywords'] = ";".join(body['keywords'])
            row['dataset_year'] = parser.parse(body['publicationDate']).strftime('%Y')


with open('interaction_datasets_zotero.csv', 'r') as csvfile, open('interaction_datasets_final.csv', 'w') as new_csvfile:
    reader = csv.DictReader(csvfile)
    writer = csv.DictWriter(new_csvfile, fieldnames=reader.fieldnames)
    writer.writeheader()

    for row in reader:
        try :
            if row['structure_schema'] == 'DWCA':
                if row['format'] == 'RSS':
                    new_rows = get_dwca_endpoints_from_rss(row)
                    for r in new_rows:
                        writer.writerow(r)
                elif row['format'] == 'ZIP':
                    get_dwca_endpoints_from_gbif(row)
                    writer.writerow(row)
            elif row['data_repository_host_by'] == 'Dryad':
                get_dryad_metadata(row)
                writer.writerow(row)
            else:
                writer.writerow(row)
        except Exception as e:
            print(row)

