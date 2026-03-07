package lml.intellectualproperty;

import edu.harvard.seas.pl.abcdatalog.ast.Clause;
import edu.harvard.seas.pl.abcdatalog.ast.PositiveAtom;
import edu.harvard.seas.pl.abcdatalog.engine.DatalogEngine;
import edu.harvard.seas.pl.abcdatalog.engine.bottomup.sequential.SemiNaiveEngine;
import edu.harvard.seas.pl.abcdatalog.parser.DatalogParser;
import edu.harvard.seas.pl.abcdatalog.parser.DatalogTokenizer;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.io.StringReader;
import java.util.Set;
import java.util.stream.Collectors;

public class DatalogEngineWrapper {

    private final DatalogEngine engine;

    public DatalogEngineWrapper(String resourceName) throws Exception {
        this.engine = new SemiNaiveEngine(false);
        InputStream is = getClass().getResourceAsStream(resourceName);
        if (is == null) throw new IllegalArgumentException("File not found: " + resourceName);

        DatalogTokenizer tokenizer = new DatalogTokenizer(new InputStreamReader(is));
        Set<Clause> program = DatalogParser.parseProgram(tokenizer);
        engine.init(program);
    }

    public Set<String> query(String queryStr) throws Exception {
        DatalogTokenizer queryTokenizer = new DatalogTokenizer(new StringReader(queryStr));
        PositiveAtom query = DatalogParser.parseQuery(queryTokenizer);
        Set<PositiveAtom> results = engine.query(query);

        // Convert PositiveAtoms to Strings for easier assertion
        return results.stream()
                .map(PositiveAtom::toString)
                .collect(Collectors.toSet());
    }
}
