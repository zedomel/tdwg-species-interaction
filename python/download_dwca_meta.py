import requests
import zipfile
import csv
from dwca.descriptors import ArchiveDescriptor

def download(url):
    get_response = requests.get(url,stream=True)
    file_name  = url.split("/")[-1]
    with open(file_name, 'wb') as f:
        for chunk in get_response.iter_content(chunk_size=1024):
            if chunk: # filter out keep-alive new chunks
                f.write(chunk)
    return file_name


def get_meta_xml(file):
    with zipfile.ZipFile(file, 'r') as archive:
        with archive.open('meta.xml') as metaxml:
            with open(f'{file}_meta.xml', 'wb') as f:
                f.write(metaxml.read())
    return f'{file}_meta.xml'



def read_meta_xml(metaxml):
    with open(metaxml, 'r') as f:
        return ArchiveDescriptor(f.read())

def extract_terms(ard):

    with open('terms.csv', 'w') as outfile:
        writer = csv.writer(outfile)
        writer.writerow([
            ard.core.type,
            ';'.join([f['term'] for f in ard.core.fields]),
            ';'.join([e.type for e in ard.extensions]),
            ';'.join([f['term'] for e in ard.extensions for f in e.fields])
        ])


file = download("http://ipt.saiab.ac.za/archive.do?r=catalogueofafrotropicalbees")
metafile = get_meta_xml(file)
archive_descriptor = read_meta_xml(metafile)
extract_terms(archive_descriptor)
