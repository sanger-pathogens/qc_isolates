def validateManifest(manifestFile) {
    try {
        def file = new File(manifestFile)
        if (!file.exists()) throw new Exception("Manifest file not found: ${manifestFile}")

        def lines = file.readLines()
        if (lines.size() < 2) throw new Exception("Manifest file is empty or has no data rows")

        // Parse header
        def header = lines[0].split(',')*.trim()
        def idIndex = header.indexOf('ID')
        if (idIndex == -1) throw new Exception("Manifest must contain an 'ID' column")
        def dirIndex = header.indexOf('assembly_dir')
        if (dirIndex == -1) throw new Exception("Manifest must contain an 'assembly_dir' column")

        def unexpectedColumns = header.findAll { !['ID', 'assembly_dir'].contains(it) }
        if (unexpectedColumns) {
            log.warn("The following unexpected columns were found in the manifest: ${unexpectedColumns}")
        }

        // Process each line
        lines.drop(1).eachWithIndex { line, lineNum ->
            def values = line.split(',')*.trim()
            def id = values[idIndex]
            def assembly_dir = new File(values[dirIndex])

            if (!id) throw new Exception("Missing ID at line ${lineNum+1}")
            if (!assembly_dir) throw new Exception("Missing Directory at line ${lineNum+1}")
            if (!assembly_dir.exists()) throw new Exception("Directory does not exist at the given path '${assembly_dir}' at line ${lineNum+1}")
        }

        // Return manifest path on success
        return file.absolutePath

    } catch (Exception e) {
        throw new Exception("Manifest validation failed:\n${e.message}")
    }
}
