// get all nodes
MATCH (n) RETURN n;

// get all nodes with relations
MATCH p=(a)-->(b) RETURN p;

// get tag with id = 3 and resource with id = 4 and connect them
MATCH (t:Tag {tagId: 3}) MATCH (r:Resource {resourceId: 4}) CREATE (t)-[:OWNED]->(a);

// return resources qty
MATCH (r:Resource) RETURN count(r) AS resource_count;

// create indeces on tagId and resourceId and use it
CREATE INDEX ON :Tag(tagId);
CREATE INDEX ON :Resource(resourceId);

// create resource
CREATE (:Resource {resourceId: 1, url: 'https://example.com'});

// create tag
CREATE (:Tag {tagId: 1, name: 'lifehack'});

// create double sided relationship between tag and resource
MATCH (r:Resource {resourceId: 1}) MATCH (t:Tag {tagId: 2}) CREATE (r)-[:HAS]->(t), (t)-[:OWNED]->(r);

PROFILE
MATCH o=(t:Tag {tagId: 1})-->(r) RETURN r;

MATCH (t:Tag) WHERE t.tagId IN [3, 5] RETURN t;

PROFILE
MATCH o=(t:Tag)-->(r) WHERE t.tagId IN [1, 2, 3] RETURN r;
// Cypher version: CYPHER 3.5, planner: COST, runtime: COMPILED. 80427 total db hits in 872 ms
