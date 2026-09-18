package lml.intellectualproperty;

import org.junit.jupiter.api.Test;

import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Regression tests for the legacy EMR artifact.
 *
 * These tests freeze observed legacy behavior before the PAMoLa-aligned
 * refactoring. They are deliberately not described as an independent semantic
 * oracle.
 */
class EmrSemanticRegressionTest {

    private static final String RESOURCE = "/New_EMR.pl";

    private static final List<String> SUBJECTS = List.of(
            "bobSmith",
            "elonMusk",
            "charlieChaplin",
            "jamesMcGill",
            "jordanDoletta",
            "manoDelon",
            "fatimaLoren"
    );

    private static final List<String> RECORDS = List.of(
            "orthoRecJ",
            "generalRecK",
            "generalRecT",
            "hivRecL"
    );

    private static final List<String> ACTIONS = List.of("view", "add");

    @Test
    void legacyWorkloadContains56RequestsAnd35Allows() throws Exception {
        DatalogEngineWrapper engine = new DatalogEngineWrapper(RESOURCE);

        int total = 0;
        int allowed = 0;

        for (String subject : SUBJECTS) {
            for (String object : RECORDS) {
                for (String action : ACTIONS) {
                    total++;
                    String query = String.format(
                            "has_access(%s, %s, %s)?",
                            subject, object, action);
                    if (!engine.query(query).isEmpty()) {
                        allowed++;
                    }
                }
            }
        }

        assertEquals(56, total);
        assertEquals(35, allowed,
                "Aggregate equality is only a regression check, not an independent oracle.");
    }

    @Test
    void instanceDenialDecidesJordanGeneralRecordViewAtO3() throws Exception {
        DatalogEngineWrapper engine = new DatalogEngineWrapper(RESOURCE);

        assertTrue(engine.query(
                "has_access(jordanDoletta, generalRecK, view)?").isEmpty());

        assertFalse(engine.query(
                "has_prohibition(jordanDoletta, generalRecK, view)?").isEmpty());

        assertFalse(engine.query(
                "deciding_level(jordanDoletta, generalRecK, view, o3)?").isEmpty());
    }

    @Test
    void legacyWorkloadHasNoSurvivingSameLevelConflict() throws Exception {
        DatalogEngineWrapper engine = new DatalogEngineWrapper(RESOURCE);

        int conflicts = 0;

        for (String subject : SUBJECTS) {
            for (String object : RECORDS) {
                for (String action : ACTIONS) {
                    String query = String.format(
                            "true_conflict(%s, %s, %s)?",
                            subject, object, action);
                    if (!engine.query(query).isEmpty()) {
                        conflicts++;
                    }
                }
            }
        }

        assertEquals(0, conflicts);
    }
}
