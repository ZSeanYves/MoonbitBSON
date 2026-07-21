# MongoDB BSON Corpus

These fixtures are copied from MongoDB Rust BSON 3.1.0 commit
`8b8bdd3ea4d8e22cdb68169d762d8facb1b12e73`.

Upstream specification and license information:
<https://github.com/mongodb/specifications/tree/master/source/bson-corpus>

Run `node tools/generate-corpus-tests.mjs` after updating the JSON files. The
generated `src/full_corpus_test.mbt` is committed so all MoonBit backends can
run the corpus without filesystem access.
