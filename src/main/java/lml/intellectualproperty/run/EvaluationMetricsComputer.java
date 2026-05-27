package lml.intellectualproperty.run;

import lml.intellectualproperty.DatalogEngineWrapper;

import java.io.BufferedReader;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.*;

/**
 * Workload-based evaluation for the SACMAT EMR artifact.
 * <p>
 * Requires that New_EMR_SACMAT.txt includes the "METRICS LAYER" predicates:
 * deciding_level/4, applicable_at_level/6, winner_at_level/5, shadowed_at_level/5,
 * preempted_level/4, true_conflict/3.
 */
public class EvaluationMetricsComputer {

    private static final String RESOURCE = "/New_EMR.txt";
    private static final List<String> LEVELS = List.of("o0", "o1", "o2", "o3");
    private static final List<String> ACTIONS = List.of("view", "add");

    // Minimal workload lists taken from the executable artifact’s concrete individuals/records.
    // You can extend these lists later (or generate them by parsing the file).
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
        @Override
        public String toString() {
            return "⟨" + s + "," + o + "," + a + "⟩";
        }
    }

    public static void main(String[] args) throws Exception {
        try {
            // 0) File statistics (engineering-effort proxies)
            printResourceStats(RESOURCE);

            // 1) Build engine
            DatalogEngineWrapper engine = new DatalogEngineWrapper(RESOURCE);

            // 2) Build workload
            List<Request> workload = buildWorkload(SUBJECTS, RECORDS, ACTIONS);
            System.out.println("\nWorkload size = " + workload.size() + " requests");

            // Workload-size scaling (N-scaling)
            /*runWorkloadScaling(
                    engine,
                    workload,
                    new int[]{8, 16, 32, 64}, // you can extend later
                    1,  // warmupRounds
                    5   // measuredRounds
            );*/

            runWorkloadScalingRepeated(
                    engine,
                    workload,
                    new int[]{56, 224, 896, 3584, 14336, 57344, 100000},
                    2,  // warmupRounds
                    5   // measuredRounds
            );

            List<Request> applicableWorkload = filterApplicableRequests(engine, workload);
            System.out.println("Applicable workload size = " + applicableWorkload.size());

            runWorkloadScalingRepeated(
                    engine,
                    applicableWorkload,
                    new int[]{56, 224, 896, 3584, 14336, 57344, 100000},
                    2,
                    5
            );

            // 3) Run workload and collect metrics
            List<Double> latMicros = new ArrayList<>(workload.size());
            List<Integer> explSizes = new ArrayList<>(workload.size());

            int allowCount = 0;
            Map<String, Integer> allowByAction = new HashMap<>();
            Map<String, Integer> totalByAction = new HashMap<>();

            int conflictCount = 0;

            // per-level accumulators
            Map<String, Long> sumApplicable = new HashMap<>();
            Map<String, Long> sumShadowed = new HashMap<>();
            Map<String, Long> sumWinners = new HashMap<>();
            Map<String, Long> sumPreempted = new HashMap<>();

            // for average shadow ratio per level (only when applicable>0)
            Map<String, Double> sumShadowRatio = new HashMap<>();
            Map<String, Long> shadowRatioDenom = new HashMap<>();

            long totalQueryNanos = 0L;

            for (Request r : workload) {
                totalByAction.merge(r.a, 1, Integer::sum);

                // ---- Decision + latency (timing has_access) ----
                String hasAccessQ = String.format("has_access(%s, %s, %s)?", r.s, r.o, r.a);
                long t0 = System.nanoTime();
                boolean allowed = !engine.query(hasAccessQ).isEmpty();
                long t1 = System.nanoTime();

                long dt = (t1 - t0);
                totalQueryNanos += dt;
                double micros = dt / 1_000.0;

                latMicros.add(micros);
                if (allowed) {
                    allowCount++;
                    allowByAction.merge(r.a, 1, Integer::sum);
                }

                // ---- Refinement / structure per level ----
                long requestExplSize = 0;

                for (String L : LEVELS) {
                    int applicable = engine.query(String.format(
                            "applicable_at_level(%s, %s, %s, %s, RuleId, Pol)?", r.s, r.o, r.a, L)).size();

                    int shadowed = engine.query(String.format(
                            "shadowed_at_level(%s, %s, %s, %s, RuleId)?", r.s, r.o, r.a, L)).size();

                    int winners = engine.query(String.format(
                            "winner_at_level(%s, %s, %s, %s, Pol)?", r.s, r.o, r.a, L)).size();

                    sumApplicable.merge(L, (long) applicable, Long::sum);
                    sumShadowed.merge(L, (long) shadowed, Long::sum);
                    sumWinners.merge(L, (long) winners, Long::sum);

                    requestExplSize += (long) applicable + shadowed;

                    if (applicable > 0) {
                        sumShadowRatio.merge(L, (double) shadowed / (double) applicable, Double::sum);
                        shadowRatioDenom.merge(L, 1L, Long::sum);
                    }
                }

                int preemptedLevels = engine.query(String.format(
                        "preempted_level(%s, %s, %s, L)?", r.s, r.o, r.a)).size();
                sumPreempted.merge("all", (long) preemptedLevels, Long::sum);

                requestExplSize += preemptedLevels;
                explSizes.add((int) requestExplSize);

                boolean conflict = !engine.query(String.format(
                        "true_conflict(%s, %s, %s)?", r.s, r.o, r.a)).isEmpty();
                if (conflict) conflictCount++;
            }

            // 4) Summaries
            System.out.println("\n================== RESULTS ==================");

            // decision rates
            double allowRate = workload.isEmpty() ? 0.0 : (100.0 * allowCount / workload.size());
            System.out.printf("Allow rate: %d/%d (%.1f%%)%n", allowCount, workload.size(), allowRate);
            for (String a : ACTIONS) {
                int tot = totalByAction.getOrDefault(a, 0);
                int alw = allowByAction.getOrDefault(a, 0);
                double rate = tot == 0 ? 0.0 : (100.0 * alw / tot);
                System.out.printf("  - %s: %d/%d (%.1f%%)%n", a, alw, tot, rate);
            }

            // latency percentiles
            Collections.sort(latMicros);
            System.out.printf("%nLatency (has_access): p50=%.2fµs p95=%.2fµs mean=%.2fµs max=%.2fµs%n",
                    percentile(latMicros, 50),
                    percentile(latMicros, 95),
                    mean(latMicros),
                    latMicros.isEmpty() ? 0.0 : latMicros.get(latMicros.size() - 1)
            );

            double seconds = totalQueryNanos / 1_000_000_000.0;
            double throughput = seconds == 0.0 ? 0.0 : workload.size() / seconds;
            System.out.printf("Throughput (serial, has_access only): %.1f decisions/sec%n", throughput);

            // conflicts
            double conflictRate = workload.isEmpty() ? 0.0 : (100.0 * conflictCount / workload.size());
            System.out.printf("%nTrue conflict rate: %d/%d (%.2f%%)%n", conflictCount, workload.size(), conflictRate);

            // per-level refinement stats
            System.out.println("\nPer-level refinement aggregates (summed over workload):");
            for (String L : LEVELS) {
                long a0 = sumApplicable.getOrDefault(L, 0L);
                long sh = sumShadowed.getOrDefault(L, 0L);
                long win = sumWinners.getOrDefault(L, 0L);
                double globalShadowRatio = a0 == 0 ? 0.0 : (double) sh / (double) a0;

                double avgShadowRatio = 0.0;
                long denom = shadowRatioDenom.getOrDefault(L, 0L);
                if (denom > 0) avgShadowRatio = sumShadowRatio.getOrDefault(L, 0.0) / denom;

                System.out.printf("  %s: applicable=%d shadowed=%d winners=%d  globalShadowRatio=%.3f  avgShadowRatio=%.3f%n",
                        L, a0, sh, win, globalShadowRatio, avgShadowRatio);
            }

            long totalPreempted = sumPreempted.getOrDefault("all", 0L);
            double avgPreempted = workload.isEmpty() ? 0.0 : (double) totalPreempted / workload.size();
            System.out.printf("%nPreemption depth proxy: totalPreempted=%d  avgPreemptedPerRequest=%.3f%n",
                    totalPreempted, avgPreempted);

            // explanation size distribution
            Collections.sort(explSizes);
            System.out.printf("%nExplanation-size proxy (Σ applicable + Σ shadowed + preemptedLevels): p50=%d p95=%d mean=%.2f max=%d%n",
                    percentileInt(explSizes, 50),
                    percentileInt(explSizes, 95),
                    meanInt(explSizes),
                    explSizes.isEmpty() ? 0 : explSizes.get(explSizes.size() - 1)
            );

            System.out.println("=============================================\n");

        }catch (Exception e){
            e.printStackTrace();
        }
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

    private static double mean(List<Double> xs) {
        if (xs.isEmpty()) return 0.0;
        double sum = 0.0;
        for (double x : xs) sum += x;
        return sum / xs.size();
    }

    private static double percentile(List<Double> sorted, int p) {
        if (sorted.isEmpty()) return 0.0;
        if (p <= 0) return sorted.get(0);
        if (p >= 100) return sorted.get(sorted.size() - 1);
        double idx = (p / 100.0) * (sorted.size() - 1);
        int lo = (int) Math.floor(idx);
        int hi = (int) Math.ceil(idx);
        if (lo == hi) return sorted.get(lo);
        double w = idx - lo;
        return sorted.get(lo) * (1.0 - w) + sorted.get(hi) * w;
    }

    private static double meanInt(List<Integer> xs) {
        if (xs.isEmpty()) return 0.0;
        long sum = 0;
        for (int x : xs) sum += x;
        return (double) sum / xs.size();
    }

    private static int percentileInt(List<Integer> sorted, int p) {
        if (sorted.isEmpty()) return 0;
        if (p <= 0) return sorted.get(0);
        if (p >= 100) return sorted.get(sorted.size() - 1);
        double idx = (p / 100.0) * (sorted.size() - 1);
        return sorted.get((int) Math.round(idx));
    }

    private static void printResourceStats(String resource) throws Exception {
        InputStream is = EvaluationMetricsComputer.class.getResourceAsStream(resource);
        if (is == null) {
            System.out.println("Could not read resource for stats: " + resource);
            return;
        }
        long lines = 0;
        long declaredPolicies = 0;
        long satisfiesRules = 0;
        long factsLikely = 0;

        try (BufferedReader br = new BufferedReader(new InputStreamReader(is, StandardCharsets.UTF_8))) {
            String line;
            while ((line = br.readLine()) != null) {
                lines++;
                String t = line.trim();
                if (t.isEmpty() || t.startsWith("%")) continue;

                if (t.contains("declared_policy(")) declaredPolicies++;
                if (t.startsWith("satisfies(")) satisfiesRules++;

                // very rough “fact” proxy: ground atom ending with '.' and not a rule head (no ':-')
                if (t.endsWith(".") && !t.contains(":-")) factsLikely++;
            }
        }

        System.out.println("Resource stats for " + resource);
        System.out.println("  lines=" + lines);
        System.out.println("  declared_policy facts=" + declaredPolicies);
        System.out.println("  satisfies rules=" + satisfiesRules);
        System.out.println("  approx. ground facts=" + factsLikely);
    }

    private static void runWorkloadScaling(
            DatalogEngineWrapper engine,
            List<Request> workload,
            int[] Ns,
            int warmupRounds,
            int measuredRounds
    ) throws Exception {
        // Warm-up (helps reduce JIT/GC noise)
        for (int i = 0; i < warmupRounds; i++) {
            for (Request r : workload) {
                engine.query(String.format("has_access(%s, %s, %s)?", r.s, r.o, r.a));
            }
        }

        System.out.println("\n=========== WORKLOAD-SIZE SCALING (has_access) ===========");
        System.out.println("N | p50(µs) | p95(µs) | mean(µs) | max(µs) | decisions/sec");
        System.out.println("----------------------------------------------------------");

        for (int N : Ns) {
            int n = Math.min(N, workload.size());
            List<Request> slice = workload.subList(0, n);

            // Run multiple measured rounds and aggregate by taking the median of p95 (robust)
            List<Double> p50s = new ArrayList<>();
            List<Double> p95s = new ArrayList<>();
            List<Double> means = new ArrayList<>();
            List<Double> maxs = new ArrayList<>();
            List<Double> throughputs = new ArrayList<>();

            for (int round = 0; round < measuredRounds; round++) {
                List<Double> latMicros = new ArrayList<>(n);
                long totalNanos = 0L;

                for (Request r : slice) {
                    String q = String.format("has_access(%s, %s, %s)?", r.s, r.o, r.a);
                    long t0 = System.nanoTime();
                    engine.query(q);
                    long t1 = System.nanoTime();
                    long dt = (t1 - t0);
                    totalNanos += dt;
                    latMicros.add(dt / 1_000.0);
                }

                Collections.sort(latMicros);
                double p50 = percentile(latMicros, 50);
                double p95 = percentile(latMicros, 95);
                double mean = mean(latMicros);
                double max = latMicros.isEmpty() ? 0.0 : latMicros.get(latMicros.size() - 1);

                double seconds = totalNanos / 1_000_000_000.0;
                double thr = seconds == 0.0 ? 0.0 : n / seconds;

                p50s.add(p50);
                p95s.add(p95);
                means.add(mean);
                maxs.add(max);
                throughputs.add(thr);
            }

            // Sort and take median across rounds (robust summary)
            Collections.sort(p50s);
            Collections.sort(p95s);
            Collections.sort(means);
            Collections.sort(maxs);
            Collections.sort(throughputs);

            double p50Med = p50s.get(p50s.size() / 2);
            double p95Med = p95s.get(p95s.size() / 2);
            double meanMed = means.get(means.size() / 2);
            double maxMed = maxs.get(maxs.size() / 2);
            double thrMed = throughputs.get(throughputs.size() / 2);

            System.out.printf("%d | %.2f | %.2f | %.2f | %.2f | %.1f%n",
                    n, p50Med, p95Med, meanMed, maxMed, thrMed);
        }

        System.out.println("==========================================================\n");
    }

    private static void runWorkloadScalingRepeated(
            DatalogEngineWrapper engine,
            List<Request> baseWorkload,
            int[] Ns,
            int warmupRounds,
            int measuredRounds
    ) throws Exception {
        // Warm-up
        for (int i = 0; i < warmupRounds; i++) {
            for (Request r : baseWorkload) {
                engine.query(String.format("has_access(%s, %s, %s)?", r.s, r.o, r.a));
            }
        }

        System.out.println("\n=========== VOLUME SCALING (repeated workload; has_access) ===========");
        System.out.println("N | p50(µs) | p95(µs) | tmean(µs) | mean(µs) | max(µs) | decisions/sec");
        System.out.println("---------------------------------------------------------------------");

        List<Integer> NsUsed = new ArrayList<>();
        List<Double> tmeanMeds = new ArrayList<>();
        List<Double> p95Meds = new ArrayList<>();

        for (int N : Ns) {
            if (N <= 0) continue;

            List<Double> p50s = new ArrayList<>();
            List<Double> p95s = new ArrayList<>();
            List<Double> tmeans = new ArrayList<>();
            List<Double> means = new ArrayList<>();
            List<Double> maxs = new ArrayList<>();
            List<Double> throughputs = new ArrayList<>();

            for (int round = 0; round < measuredRounds; round++) {
                List<Double> latMicros = new ArrayList<>(Math.min(N, 20000));
                // For huge N, storing every latency can be memory-heavy.
                // We'll sample latencies (see below) to keep memory bounded.

                long totalNanos = 0L;

                // Sample settings: store every k-th latency so memory stays small
                int sampleTarget = 20000; // store up to ~20k samples
                int k = Math.max(1, N / sampleTarget);

                for (int i = 0; i < N; i++) {
                    Request r = baseWorkload.get(i % baseWorkload.size());
                    String q = String.format("has_access(%s, %s, %s)?", r.s, r.o, r.a);

                    long t0 = System.nanoTime();
                    engine.query(q);
                    long t1 = System.nanoTime();

                    long dt = (t1 - t0);
                    totalNanos += dt;

                    if (i % k == 0) {
                        latMicros.add(dt / 1_000.0);
                    }
                }

                Collections.sort(latMicros);
                double p50 = percentile(latMicros, 50);
                double p95 = percentile(latMicros, 95);
                double tmean = trimmedMean(latMicros, 0.025); // EBAC-style: drop 2.5% low/high
                double mean = mean(latMicros);
                double max = latMicros.isEmpty() ? 0.0 : latMicros.get(latMicros.size() - 1);

                double seconds = totalNanos / 1_000_000_000.0;
                double thr = seconds == 0.0 ? 0.0 : N / seconds;

                p50s.add(p50);
                p95s.add(p95);
                tmeans.add(tmean);
                means.add(mean);
                maxs.add(max);
                throughputs.add(thr);
            }

            Collections.sort(p50s);
            Collections.sort(p95s);
            Collections.sort(tmeans);
            Collections.sort(means);
            Collections.sort(maxs);
            Collections.sort(throughputs);

            double p50Med = p50s.get(p50s.size() / 2);
            double p95Med = p95s.get(p95s.size() / 2);
            double tmeanMed = tmeans.get(tmeans.size() / 2);
            double meanMed = means.get(means.size() / 2);
            double maxMed = maxs.get(maxs.size() / 2);
            double thrMed = throughputs.get(throughputs.size() / 2);

            NsUsed.add(N);
            tmeanMeds.add(tmeanMed);
            p95Meds.add(p95Med);

            System.out.printf("%d | %.2f | %.2f | %.2f | %.2f | %.1f%n",
                    N, p50Med, p95Med, tmeanMed, meanMed, maxMed, thrMed);
        }

        System.out.println("\nGradients (Δ per log2 step):");
        System.out.println("From N -> To N | Δtmean (µs) | Δp95 (µs) | per doubling interpretation");

        for (int i = 1; i < NsUsed.size(); i++) {
            int n1 = NsUsed.get(i - 1);
            int n2 = NsUsed.get(i);

            double dt = tmeanMeds.get(i) - tmeanMeds.get(i - 1);
            double dp = p95Meds.get(i) - p95Meds.get(i - 1);

            // normalize by log2(n2/n1) so it's "per doubling"
            double steps = Math.log((double) n2 / (double) n1) / Math.log(2.0);
            if (steps == 0.0) steps = 1.0;

            double dtPerDoubling = dt / steps;
            double dpPerDoubling = dp / steps;

            System.out.printf("%6d -> %-6d | %10.4f | %9.4f | (µs change per doubling)%n",
                    n1, n2, dtPerDoubling, dpPerDoubling);
        }

        System.out.println("======================================================================\n");
    }

    private static double trimmedMean(List<Double> sorted, double trimFraction) {
        if (sorted.isEmpty()) return 0.0;
        if (trimFraction < 0.0) trimFraction = 0.0;
        if (trimFraction >= 0.5) trimFraction = 0.49;

        int n = sorted.size();
        int k = (int) Math.floor(n * trimFraction);
        int from = k;
        int to = n - k; // exclusive
        if (from >= to) return mean(sorted);

        double sum = 0.0;
        for (int i = from; i < to; i++) sum += sorted.get(i);
        return sum / (to - from);
    }

    private static List<Request> filterApplicableRequests(DatalogEngineWrapper engine, List<Request> workload) throws Exception {
        List<Request> out = new ArrayList<>();
        for (Request r : workload) {
            String q = String.format("deciding_level(%s, %s, %s, L)?", r.s, r.o, r.a);
            if (!engine.query(q).isEmpty()) out.add(r);
        }
        return out;
    }
}
