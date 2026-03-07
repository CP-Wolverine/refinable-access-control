package lml.intellectualproperty.run;

import lml.intellectualproperty.DatalogEngineWrapper;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ChangeImpactDiffRunner {

    private static final String BASE = "/New_EMR_SACMAT.txt";
    private static final String MOD  = "/New_EMR_SACMAT_v2.txt";

    private static final List<String> ACTIONS = List.of("view", "add");

    // Keep workload consistent with EvaluationMetricsComputer (or import/share)
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

    private record Request(String s, String o, String a) {
        @Override public String toString() { return "⟨" + s + "," + o + "," + a + "⟩"; }
    }

    public static void main(String[] args) throws Exception {
        DatalogEngineWrapper base = new DatalogEngineWrapper(BASE);
        DatalogEngineWrapper mod  = new DatalogEngineWrapper(MOD);

        List<Request> workload = buildWorkload(SUBJECTS, RECORDS, ACTIONS);

        for (Request r : workload) {
            if (base.query(String.format("deciding_level(%s,%s,%s,L)?", r.s, r.o, r.a)).isEmpty()) {
                System.out.println("No deciding level: " + r);
            }
        }

        int changed = 0;
        Map<String, Integer> changedByAction = new HashMap<>();
        Map<String, Integer> totalByAction = new HashMap<>();

        List<String> examples = new ArrayList<>();

        for (Request r : workload) {
            totalByAction.merge(r.a, 1, Integer::sum);

            boolean b = isAllowed(base, r);
            boolean m = isAllowed(mod, r);

            if (b != m) {
                changed++;
                changedByAction.merge(r.a, 1, Integer::sum);

                if (examples.size() < 15) {
                    examples.add(r + " : " + (b ? "ALLOW" : "DENY") + " → " + (m ? "ALLOW" : "DENY"));
                }
            }
        }

        System.out.println("Baseline: " + BASE);
        System.out.println("Modified: " + MOD);
        System.out.println("Workload size = " + workload.size());

        double changeRate = workload.isEmpty() ? 0.0 : (100.0 * changed / workload.size());
        System.out.printf("%nChange impact radius: %d/%d (%.2f%%)%n", changed, workload.size(), changeRate);

        for (String a : ACTIONS) {
            int tot = totalByAction.getOrDefault(a, 0);
            int chg = changedByAction.getOrDefault(a, 0);
            double rate = tot == 0 ? 0.0 : (100.0 * chg / tot);
            System.out.printf("  - %s: %d/%d (%.2f%%)%n", a, chg, tot, rate);
        }

        System.out.println("\nExample flipped decisions:");
        if (examples.isEmpty()) {
            System.out.println("  (none)");
        } else {
            for (String e : examples) System.out.println("  " + e);
        }
    }

    private static boolean isAllowed(DatalogEngineWrapper engine, Request r) throws Exception {
        String q = String.format("has_access(%s, %s, %s)?", r.s, r.o, r.a);
        return !engine.query(q).isEmpty();
    }

    private static List<Request> buildWorkload(List<String> subjects, List<String> objects, List<String> actions) {
        List<Request> reqs = new ArrayList<>();
        for (String s : subjects) {
            for (String o : objects) {
                for (String a : actions) {
                    reqs.add(new Request(s, o, a));
                }
            }
        }
        return reqs;
    }
}