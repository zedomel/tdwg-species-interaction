import os
import bigjson
import asyncio
import asyncpg
import shapely.geometry
import shapely.wkb
import csv

from sys import argv
from shapely.geometry.base import BaseGeometry

async def writeLog(props):
    with open('error-data.txt', 'a') as file:
        file.write(','.join(props.values()))
        file.write('\n')


async def define_geom_type(conn):
    try:
        def encode_geometry(geometry):
            if not hasattr(geometry, '__geo_interface__'):
                raise TypeError('{g} does not conform to '
                    'the geo interface'.format(g=geometry))
            shape = shapely.geometry.asShape(geometry)
            return shapely.wkb.dumps(shape, srid=4326)
        def decode_geometry(wkb):
            return shapely.wkb.loads(wkb)

        await conn.set_type_codec(
            'geometry',  # also works for 'geography'
            encoder=encode_geometry,
            decoder=decode_geometry,
            format='binary',
        )
    except Exception as e:
        raise e

async def main() :
    user='postgres'
    password='FwQE32adsrkSTUj'
    database='globi'
    host='geodb.cldo1feu6uzi.us-east-2.rds.amazonaws.com'
    props_names = ['locality','type','localityId','bodyPartId','lifeStageId','bodyPartLabel',
            'lifeStageLabel','externalUrl','kingdomId','kingdomName','phylumId','phylumName','classId','className',
            'orderId','orderName','familyId','familyName','genusId','genusName','speciesId','speciesName','externalId','name','rank']

    script, in_file = argv

    conn = await asyncpg.connect(user=user, password=password,
        database=database, host=host)
    await define_geom_type(conn)

    stmt = await conn.prepare('''INSERT INTO observations (locality,type,localityId,bodyPartId,lifeStageId,bodyPartLabel,
            lifeStageLabel,externalUrl,kingdomId,kingdomName,phylumId,phylumName,classId,className,
            orderId,orderName,familyId,familyName,genusId,genusName,speciesId,speciesName,externalId,name,rank,geom)
            VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26::geometry)''')



    with open(in_file, 'rb') as f :
        data = bigjson.load(f)
        for n in data:
            d = n['n']

            default = {k:'' for k in props_names}
            props = {**{k:v for k,v in d['loc']['properties'].iteritems()},**{k:v for k,v in d['obs']['properties'].iteritems()},**{k:v for k,v in d['sp']['properties'].iteritems()}}
            props = {**default, **props}

            data = tuple(v for k,v in props.items() if k in props_names)
            point = shapely.geometry.Point(props['longitude'], props['latitude'])
            data = data + (point,)

            if conn.is_closed():
                conn = await asyncpg.connect(user=user, password=password,
                    database=database, host=host)
                await define_geom_type(conn)
                stmt = await conn.prepare('''INSERT INTO observations (locality,type,localityId,bodyPartId,lifeStageId,bodyPartLabel,
                    lifeStageLabel,externalUrl,kingdomId,kingdomName,phylumId,phylumName,classId,className,
                    orderId,orderName,familyId,familyName,genusId,genusName,speciesId,speciesName,externalId,name,rank, geom)
                    VALUES($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15, $16, $17, $18, $19, $20, $21, $22, $23, $24, $25, $26::geometry)''')
            try:
                await stmt.executemany([data])
            except Exception as e:
                print(e)
                await writeLog(props)

    await conn.close()

asyncio.get_event_loop().run_until_complete(main())


