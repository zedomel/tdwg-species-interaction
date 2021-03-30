from sys import argv
from os.path import exists
import bigjson

script, in_file, out_file = argv

# Fix JSON file
with open(in_file, 'rb') as f :
    d