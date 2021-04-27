import requests
import os.path


from whoosh.index import create_in
from whoosh.analysis import StemmingAnalyzer
from whoosh.fields import *

from pygbif import occurrences as occ
from pygbif import registry

from dwca.read import DwCAReader
from dwca.darwincore.utils import qualname as qn


def get_index(indexDir = 'index'):
    stem_ana = StemmingAnalyzer(cachesize=-1)
    schema = Schema(uuid=TEXT(stored=True), resourceID=TEXT(stored=True), relatedResourceID=TEXT(stored=True), relationshipOfResource=TEXT(analyzer=stem_ana, stored=True), relationshipRemarks=TEXT(analyzer=stem_ana, stored=True))
    return create_in(indexDir, schema=schema, indexname="resource_relationship")


def progressBar(iterable, prefix = '', suffix = '', decimals = 1, length = 100, fill = '█', printEnd = "\r"):
    """
    Call in a loop to create terminal progress bar
    @params:
        iteration   - Required  : current iteration (Int)
        total       - Required  : total iterations (Int)
        prefix      - Optional  : prefix string (Str)
        suffix      - Optional  : suffix string (Str)
        decimals    - Optional  : positive number of decimals in percent complete (Int)
        length      - Optional  : character length of bar (Int)
        fill        - Optional  : bar fill character (Str)
        printEnd    - Optional  : end character (e.g. "\r", "\r\n") (Str)
    """
    total = len(iterable)
    # Progress Bar Printing Function
    def printProgressBar (iteration):
        percent = ("{0:." + str(decimals) + "f}").format(100 * (iteration / float(total)))
        filledLength = int(length * iteration // total)
        bar = fill * filledLength + '-' * (length - filledLength)
        print(f'\r{prefix} |{bar}| {percent}% {suffix}', end = printEnd)
    # Initial Call
    printProgressBar(0)
    # Update Progress Bar
    for i, item in enumerate(iterable):
        yield item
        printProgressBar(i + 1)
    # Print New Line on Complete
    print()

# main
limitmb = 512
procs = 6
datasetsDir = './datasets/'
indexDir = './index/'

results = occ.search(dwca_extension="http://rs.tdwg.org/dwc/terms/ResourceRelationship", limit=0, facet="datasetKey", facetLimit=1000)

ix = get_index(indexDir)

for r in progressBar(results['facets'][0]['counts'], prefix="Progress", suffix="Complete"):
    datasetKey = r['name']
    dwca_file = f'{datasetsDir}{datasetKey}.zip'

    if not os.path.isfile(dwca_file) :
        try:
            pass
            dataset = registry.datasets(uuid=datasetKey)
            dwca_endpoints = [e for e in dataset['endpoints'] if e['type'] == 'DWC_ARCHIVE']
            if len(dwca_endpoints) > 0 :
                url = dwca_endpoints[0]['url']
                req = requests.get(url, stream=True)

                with open(dwca_file, 'wb') as fd:
                    for chunk in req.iter_content(chunk_size=512) :
                        fd.write(chunk)
        except Exception as e:
            print(e)
            continue

    with DwCAReader(dwca_file) as dwca:
        try:
            for row in dwca:
                with ix.writer(limitmb=limitmb, procs=procs) as writer:
                    for ext in row.extensions:
                        if ext.rowtype == "http://rs.tdwg.org/dwc/terms/ResourceRelationship" and 'http://rs.tdwg.org/dwc/terms/relationshipOfResource' in ext.data:
                            writer.add_document(
                                uuid=datasetKey,
                                resourceID=ext.data['http://rs.tdwg.org/dwc/terms/resourceID'] if 'http://rs.tdwg.org/dwc/terms/resourceID' in ext.data else ext.core_id,
                                relatedResourceID=ext.data['http://rs.tdwg.org/dwc/terms/relatedResourceID'] if 'http://rs.tdwg.org/dwc/terms/relatedResourceID' in ext.data else None,
                                relationshipOfResource=ext.data['http://rs.tdwg.org/dwc/terms/relationshipOfResource'],
                                relationshipRemarks=(ext.data['http://rs.tdwg.org/dwc/terms/relationshipRemarks'] if 'http://rs.tdwg.org/dwc/terms/relationshipRemarks' in ext.data else None)
                            )
        except Exception as e:
            print(e)
            break




# Searching
#from whoosh.qparser import QueryParser
#with ix.searcher() as searcher:
#    query = QueryParser("content", ix.schema).parse("first")
#    results = searcher.search(query)
#    results[0]
