//
// Check input manifest and produce assembly channels
//

workflow MANIFEST_PARSE {
    take:
    manifest // file: /path/to/manifest.csv

    main:
    manifest
        .ifEmpty { exit 1, "File is empty / Cannot find file at ${manifest}" }
        .splitCsv(header:true, strip:true, sep:',')
        .map { row -> parse_row(row) }
        .set { mag_dirs }

    emit:
    mag_dirs
}

def parse_row(HashMap row) {
    def meta = [:]
    def mags_dir = null

    meta.ID = row.ID
    mags_dir = file(row.mags_dir)

    return [meta, mags_dir]
}
