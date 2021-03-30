from dwca.read import DwCAReader
from dwca.darwincore.utils import qualname as qn
from pymongo import MongoClient
from urllib.parse import quote_plus
from os import path

import dwca.darwincore.utils as utils
import csv
import requests

def saveToDB(dataset_row, dwca_row, potential_interaction_terms = []):
    col = db.interaction_records
    data = {path.basename(k):v for k,v in dwca_row.items()}
    data['ds_id'] = dataset_row['id']
    for t in potential_interaction_terms:
        key = f'has_{t}'
        data[key] = 1
    col.insert_one(data)

utils.TERMS.append('http://rs.tdwg.org/dwc/terms/associatedOrganisms')
utils.TERMS.append('http://rs.tdwg.org/dwc/terms/ResourceRelationship')
utils.TERMS.append('http://rs.tdwg.org/dwc/terms/MeasurementOrFact')

lookup_terms = [
    'associatedTaxa',
    'associatedOccurrences',
    'dynamicProperties',
    'associatedOrganisms',
    'occurrenceRemarks'
]

extensions = [
    'ResourceRelationship',
    'MeasurementOrFact'
]

host='192.168.1.3'
port=27017
user="dwca_interaction"
password="kurt1234"
database="dwca_interactions"
uri = "mongodb://%s:%s@%s:%d/%s" % (quote_plus(user), quote_plus(password), host, port, database)

client = MongoClient(uri, authSource='admin')
db = client.dwca_interactions

with open('interaction_datasets.csv', 'r') as datasetfile:
    reader = csv.DictReader(datasetfile)

    try:
        pass
    except Exception as e:
        raise e
    for csvrow in reader:
        if csvrow['structure_schema'] == 'DWCA' and csvrow['dataset_url']:
            try:
                dwca_url = csvrow['dataset_url']
                filename = csvrow['id']
                dwca_file = f'./data/dwca/{filename}.zip'

                # Download
                if not path.exists(dwca_file):
                    r = requests.get(dwca_url, stream = True)
                    with open(dwca_file, 'wb') as fd:
                        for byte in r.raw:
                            fd.write(byte)

                with DwCAReader(dwca_file) as dwca:
                    core_type = dwca.descriptor.core.type

                    has_term = {t:qn(t) in dwca.descriptor.core.terms for t in lookup_terms}
                    for row in dwca:
                        potential_interaction_terms = []
                        for term in lookup_terms:
                            if has_term[term] == True:
                                term_value = row.data[qn(term)]
                                if term_value:
                                    potential_interaction_terms.append(term)

                        for ext in row.extensions:
                            for interaction_ext in extensions:
                                if qn(interaction_ext) == ext.rowtype:
                                    saveToDB(csvrow, {**row.data, **ext.data}, [interaction_ext])

                        if len(potential_interaction_terms) > 0:
                            saveToDB(csvrow, row.data, potential_interaction_terms)
            except Exception as e:
                print(csvrow['id'])
                print(e)

client.close()