% ==================================================================================
%   PART 1: THE GENERIC KERNEL (Generalized Clabject Logic)
%   ================================================================================== */

% --- 1.1 MLM GEOMETRY (Scope Matching) --- */

% MATCHES: Does a Query Entity 'Q' fall within a Policy Scope 'S'? */
%matches(Q, S) :- Q=S.
matches(Q, S) :- hasCustodian(Q, _), Q = S.
matches(Q, S) :- isa(Q, S).

% IS_NARROWER: Is Scope 'A' a subset of Scope 'B'? */
%is_narrower(A, A).
is_narrower(A, A) :- hasCustodian(A, _).
is_narrower(A, B) :- subTypeOf(A, B).
is_narrower(A, B) :- isa(A, B).

% --- 1.2 HIERARCHY (Abstraction Levels) --- */

% Transitive Closure: Find all abstract ancestors */
is_abstract_ancestor(Abstract, Concrete) :- characterizes(Abstract, Concrete).
is_abstract_ancestor(Abstract, Concrete) :- 
    characterizes(Abstract, Mid), 
    is_abstract_ancestor(Mid, Concrete).

% --- 1.3 DISCOVERY (Binding) --- */

% Find all Rule IDs that apply to the specific Query Instances (Sq, Oq). */
applicable_policy(RuleID, Level, Policy, Sq, Oq, A) :-
    declared_policy(RuleID, Level, Policy, ScopeS, ScopeO, A, Cons),
    matches(Sq, ScopeS),
    matches(Oq, ScopeO),
    satisfies(Cons, Sq, Oq).

% --- 1.4 INTRA-LEVEL REFINEMENT (Symmetric Covariance) --- */

% Logic: SpecRule is more specific than GenRule if it is:
%   1. Narrower-or-Equal on the Subject Axis
%   2. Narrower-or-Equal on the Object Axis
%   3. Strictly Narrower on at least one Axis */
is_more_specific(SpecRuleID, GenRuleID) :-
    declared_policy(GenRuleID,  _, _, GenS,  GenO,  _, _),
    declared_policy(SpecRuleID, _, _, SpecS, SpecO, _, _),
    is_narrower(SpecS, GenS),
    is_narrower(SpecO, GenO),
    SpecO != GenO.

is_more_specific(SpecRuleID, GenRuleID) :-
    declared_policy(GenRuleID,  _, _, GenS,  GenO,  _, _),
    declared_policy(SpecRuleID, _, _, SpecS, SpecO, _, _),
    is_narrower(SpecS, GenS),
    is_narrower(SpecO, GenO),
    SpecS != GenS.

% Identify Shadowed Rules */
is_shadowed(GenRuleID, Level, Sq, Oq, A) :-
    applicable_policy(GenRuleID, Level, _, Sq, Oq, A),
    applicable_policy(SpecRuleID, Level, _, Sq, Oq, A),
    is_more_specific(SpecRuleID, GenRuleID).

% The Winner for this Level */
most_specialized_applicable_rule_at_level(Level, Policy, Sq, Oq, A) :-
    applicable_policy(RuleID, Level, Policy, Sq, Oq, A),
    not is_shadowed(RuleID, Level, Sq, Oq, A).

% --- 1.5 INTER-LEVEL SUPPRESSION (Hierarchy) --- */

is_preempted(AbstractLevel, Sq, Oq, A) :-
    most_specialized_applicable_rule_at_level(ConcreteLevel, _, Sq, Oq, A),
    is_abstract_ancestor(AbstractLevel, ConcreteLevel).

% --- 1.6 FINAL DECISION (Effective Permission) --- */

effective_permission(Sq, Oq, A) :-
    most_specialized_applicable_rule_at_level(Level, grant, Sq, Oq, A),
    not is_preempted(Level, Sq, Oq, A),
    not most_specialized_applicable_rule_at_level(Level, deny, Sq, Oq, A). % Safety Check */

effective_prohibition(Sq, Oq, A) :-
    most_specialized_applicable_rule_at_level(Level, deny, Sq, Oq, A),
    not is_preempted(Level, Sq, Oq, A).

% Public API */
has_permission(S, O, A)  :- effective_permission(S, O, A).
has_prohibition(S, O, A) :- effective_prohibition(S, O, A).

has_access(S, O, A) :- has_permission(S, O, A), not has_prohibition(S, O, A).

% ==================================================================================
%   PART 2: THE DOMAIN MODEL (EMR Data from EMR-Grok-2)
%   ================================================================================== */

% --- 2.1 HIERARCHY DEFINITION --- */
% Map the levels o0..o3 to the kernel's 'characterizes' predicate */
characterizes(o0, o1).
characterizes(o1, o2).
characterizes(o2, o3).

% --- 2.2 BASIC FACTS (Custodians & Attributes) --- */
hasCustodian(pht, o0).
hasCustodian(mrt, o0).

attribute(date).
attribute(consultationDate).
attribute(consultationEmergencyMode).
attribute(startingDate).

attribute(checkinDate).
attribute(checkinEmergencyMode).

attribute(consultDateG).
attribute(consultDateH).
attribute(consultDateI).
attribute(consultDateT).
attribute(startDateBob).
attribute(startDateAlice).
attribute(startDateCharlie).
attribute(consultEmergencyModeG).
attribute(consultEmergencyModeH).
attribute(consultEmergencyModeI).
attribute(consultEmergencyModeT).


% Level O1 */
hasCustodian(medicalRecord, o1).
hasCustodian(generalRecord, o1).
hasCustodian(orthopedicRecord, o1).
hasCustodian(hIVRecord, o1).
hasCustodian(consultation, o1).
hasCustodian(patient, o1).
hasCustodian(physician, o1).
hasCustodian(orthopedic, o1).
hasCustodian(generalist, o1). % ME
hasCustodian(hospital, o1).

hasDeclaredType(orthopedic, pht).
hasDeclaredType(generalist, pht). % ME
hasDeclaredType(generalRecord, mrt).
hasDeclaredType(orthopedicRecord, mrt).
hasDeclaredType(hIVRecord, mrt).

% Categorizations (Subtyping Logic) */
hasCustodian(sub1, c1). hasCustodian(sup1, c1). hasSubUnid(sub1, orthopedic). hasSuperUnid(sup1, physician).
hasCustodian(sub7, c7). hasCustodian(sup7, c7). hasSubUnid(sub7, generalist). hasSuperUnid(sup7, physician). %ME
hasCustodian(sub2, c2). hasCustodian(sup2, c2). hasSubUnid(sub2, generalRecord). hasSuperUnid(sup2, medicalRecord).
hasCustodian(sub3, c3). hasCustodian(sup3, c3). hasSubUnid(sub3, orthopedicRecord). hasSuperUnid(sup3, medicalRecord).
hasCustodian(sub4, c4). hasCustodian(sup4, c4). hasSubUnid(sub4, hIVRecord). hasSuperUnid(sup4, medicalRecord).

% Level O2 */
hasCustodian(trainee, o2).
hasCustodian(resident, o2).
hasCustodian(senior, o2).
hasCustodian(orthopedicTrainee, o2).
hasCustodian(orthopedicResident, o2).
hasCustodian(orthopedicSenior, o2).
hasCustodian(checkin, o2).
hasCustodian(case, o2).
hasCustodian(clinic, o2).
hasCustodian(generalRec, o2).
hasCustodian(orthopedicRec, o2).
hasCustodian(hIVRec, o2).
hasCustodian(generalTrainee, o2). % ME
hasCustodian(generalResident, o2).

hasDeclaredType(generalRec, generalRecord).
hasDeclaredType(orthopedicRec, orthopedicRecord).
hasDeclaredType(hIVRec, hIVRecord).
hasDeclaredType(case, patient).
hasDeclaredType(checkin, consultation).
hasDeclaredType(clinic, hospital).
hasDeclaredType(orthopedicTrainee, orthopedic).
hasDeclaredType(orthopedicResident, orthopedic).
hasDeclaredType(orthopedicSenior, orthopedic).
hasDeclaredType(checkinDate, consultationDate).
hasDeclaredType(checkinEmergencyMode, consultationEmergencyMode).
hasDeclaredType(employingDate, startingDate).
hasDeclaredType(generalTrainee, generalist). % ME
hasDeclaredType(generalResident, generalist).

% Categorizations (Roles) */
hasCustodian(otsu, c0). hasCustodian(tsu, c0). hasSubUnid(otsu, orthopedicTrainee). hasSuperUnid(tsu, trainee).
hasCustodian(sub5, c5). hasCustodian(sup5, c5). hasSubUnid(sub5, orthopedicResident). hasSuperUnid(sup5, resident).
hasCustodian(sub6, c6). hasCustodian(sup6, c6). hasSubUnid(sub6, orthopedicSenior). hasSuperUnid(sup6, senior).
hasCustodian(gtsu, c8). hasCustodian(tsu2, c8). hasSubUnid(gtsu, generalTrainee). hasSuperUnid(tsu2, trainee).
hasCustodian(sub9, c9). hasCustodian(sup9, c9). hasSubUnid(sub9, generalResident). hasSuperUnid(sup9, resident).


% Level O3 (Instances) */
hasCustodian(patientEve, o3).
hasCustodian(hospitalF, o3).
hasCustodian(consultG, o3).
hasCustodian(consultH, o3).
hasCustodian(consultI, o3).
hasCustodian(consultT, o3).
hasCustodian(orthoRecJ, o3).
hasCustodian(generalRecK, o3).
hasCustodian(generalRecT, o3).
hasCustodian(hivRecL, o3).
hasCustodian(bobSmith, o3).
hasCustodian(elonMusk, o3).
hasCustodian(charlieChaplin, o3).
hasCustodian(jamesMcGill, o3).
%hasCustodian(generalPhys, o3).
hasCustodian(jordanDoletta, o3).
hasCustodian(manoDelon, o3).
hasCustodian(fatimaLoren, o3).

hasDeclaredType(patientEve, patient).
hasDeclaredType(hospitalF, hospital).
hasDeclaredType(consultG, checkin).
hasDeclaredType(consultH, checkin).
hasDeclaredType(consultI, checkin).
hasDeclaredType(consultT, checkin).
hasDeclaredType(orthoRecJ, orthopedicRec).
hasDeclaredType(generalRecK, generalRec).
hasDeclaredType(generalRecT, generalRec).
hasDeclaredType(hivRecL, hIVRec).
hasDeclaredType(bobSmith, orthopedicTrainee).
hasDeclaredType(elonMusk, orthopedicResident).
hasDeclaredType(charlieChaplin, orthopedicSenior).
hasDeclaredType(jamesMcGill, orthopedicSenior).
%hasDeclaredType(generalPhys, physician).
hasDeclaredType(jordanDoletta, generalTrainee).
hasDeclaredType(manoDelon, generalTrainee).
hasDeclaredType(fatimaLoren, generalResident).


% Attributes & Values */
hasCustodian(consultEmergencyModeG, consultG). hasValue(consultEmergencyModeG, true). hasDeclaredType(consultEmergencyModeG, checkinEmergencyMode).
hasCustodian(consultEmergencyModeH, consultH). hasValue(consultEmergencyModeH, false). hasDeclaredType(consultEmergencyModeH, checkinEmergencyMode).
hasCustodian(consultEmergencyModeI, consultI). hasValue(consultEmergencyModeI, false). hasDeclaredType(consultEmergencyModeI, checkinEmergencyMode).
hasCustodian(consultEmergencyModeT, consultT). hasValue(consultEmergencyModeT, false). hasDeclaredType(consultEmergencyModeT, checkinEmergencyMode).
hasCustodian(consultDateG, consultG). hasValue(consultDateG, 2025). hasDeclaredType(consultDateG, checkinDate).
hasCustodian(consultDateH, consultH). hasValue(consultDateH, 2025). hasDeclaredType(consultDateH, checkinDate).
hasCustodian(consultDateI, consultI). hasValue(consultDateI, 2020). hasDeclaredType(consultDateI, checkinDate).
hasCustodian(consultDateT, consultT). hasValue(consultDateT, 2025). hasDeclaredType(consultDateT, checkinDate).
hasCustodian(startDateBob, bobSmith). hasValue(startDateBob, 2025). hasDeclaredType(startDateBob, employingDate).
hasCustodian(startDateAlice, elonMusk). hasValue(startDateAlice, 2024). hasDeclaredType(startDateAlice, employingDate).
hasCustodian(startDateCharlie, charlieChaplin). hasValue(startDateCharlie, 2023). hasDeclaredType(startDateCharlie, employingDate).

% --- 2.3 HELPER PREDICATES (Core Logic for MLM) --- */

% Attribute Extraction */
has_attribute(X, Y, V) :- attribute(X), hasCustodian(X, Y), hasValue(X, V).

% Triples (Relationships) */
triple(Subject, Predicate, Object) :- 
    hasCustodian(P, R), hasCustodian(Q, R), P != Q,
    hasParticipant(P, Subject), hasParticipant(Q, Object),
    hasRole(P, Predicate).

% Subtyping (Recursive) */
subTypeOf(X, Y) :- hasSubUnid(S, X), hasCustodian(S, C), hasCustodian(G, C), hasSuperUnid(G, Y).
subTypeOf(X, Y) :- subTypeOf(X, A), subTypeOf(A, Y).

% Instantiation */
directInstanceOf(X, Y) :- hasDeclaredType(X, Y).
inDirectInstanceOf(X, Y) :- directInstanceOf(X, T), subTypeOf(T, Y).

shallowOffSpring(X, Y) :- directInstanceOf(X, Y).
shallowOffSpring(X, Y) :- inDirectInstanceOf(X, Y).
deepOffSpring(X, Y) :- shallowOffSpring(X, T), shallowOffSpring(T, Y).
deepOffSpring(X, Y) :- deepOffSpring(X, TT) , deepOffSpring(TT, Y).

all_instances_of(X, Y) :- shallowOffSpring(X, Y).
all_instances_of(X, Y) :- deepOffSpring(X, Y).

% ISA (Critical for Kernel) */
isa(S, T) :- all_instances_of(S, T).
isa(S, T) :- isa(S, X), isa(X, T).


% --- 2.4 RELATIONSHIPS (Connecting the Data) --- */
% (Simplified from original file for brevity - keeping critical ones for constraints) */

% r1: Patient includes Record */
relationship(r1). hasParticipant(p1, medicalRecord). hasParticipant(q1, patient). hasRole(q1, includes).
hasCustodian(p1, r1). hasCustodian(q1, r1).

% r3: Patient is Enrolled In Hospital */
relationship(r3). hasParticipant(p3, hospital). hasParticipant(q3, patient). hasRole(q3, isEnrolledIn).
hasCustodian(p3, r3). hasCustodian(q3, r3).

% r5: Physician affiliated with Hospital */
relationship(r5). hasParticipant(p5, hospital). hasParticipant(q5, physician). hasRole(q5, affiliatedWith).
hasCustodian(p5, r5). hasCustodian(q5, r5).

% r21: Consent */
relationship(r21). hasParticipant(p21, patient). hasParticipant(q21, physician). hasRole(q21, hasConsentFrom).
hasCustodian(p21, r21). hasCustodian(q21, r21).

% r26: Creator */
relationship(r26). hasParticipant(p26, medicalRecord). hasParticipant(q26, physician). hasRole(q26, creatorOf).
hasCustodian(p26, r26). hasCustodian(q26, r26).

% r37: Consultation hasRecord Record */
relationship(r37). hasParticipant(p37, medicalRecord). hasParticipant(q37, consultation). hasRole(q37, hasRecord).
hasCustodian(p37, r37). hasCustodian(q37, r37).

% r75: Checkin hasRecord General Rec */
relationship(r75). hasParticipant(p75, generalRec). hasParticipant(q75, checkin). hasRole(q75, hasRecord).
hasCustodian(p75, r75). hasCustodian(q75, r75). hasDeclaredType(r75, r37).

% r76: Checkin hasRecord Orhtopedic Rec */
relationship(r76). hasParticipant(p76, orthopedicRec). hasParticipant(q76, checkin). hasRole(q76, hasRecord).
hasCustodian(p76, r76). hasCustodian(q76, r76). hasDeclaredType(r76, r37).

% r77: Checkin hasRecord HIV Rec */
relationship(r77). hasParticipant(p77, hIVRec). hasParticipant(q77, checkin). hasRole(q77, hasRecord).
hasCustodian(p77, r77). hasCustodian(q77, r77). hasDeclaredType(r77, r37).

% r41: Supervision */
relationship(r41). hasParticipant(p41, physician). hasParticipant(q41, physician). hasRole(q41, supervises).
hasCustodian(p41, r41). hasCustodian(q41, r41).

% r4: Consultation performed by Physician */
relationship(r4). hasParticipant(p4, physician). hasParticipant(q4, consultation). hasRole(q4, isPerformedBy).
hasCustodian(p4, r4). hasCustodian(q4, r4).

% r2: Consultation involves Patient */
relationship(r2). hasParticipant(p2, patient). hasParticipant(q2, consultation). hasRole(q2, involves).
hasCustodian(p2, r2). hasCustodian(q2, r2).

% Specific Relationships (Instances) */
% PatientEve enrolled in HospitalF */
relationship(r50). hasParticipant(p50, hospitalF). hasParticipant(q50, patientEve). hasRole(q50, isEnrolledIn).
hasCustodian(p50, r50). hasCustodian(q50, r50). hasDeclaredType(r50, r3).

% Physicians affiliated with HospitalF */
relationship(r51). hasParticipant(p51, hospitalF). hasParticipant(q51, charlieChaplin). hasRole(q51, affiliatedWith). hasDeclaredType(r51, r5). hasCustodian(p51, r51). hasCustodian(q51, r51).
relationship(r52). hasParticipant(p52, hospitalF). hasParticipant(q52, elonMusk). hasRole(q52, affiliatedWith). hasDeclaredType(r52, r5). hasCustodian(p52, r52). hasCustodian(q52, r52).
relationship(r53). hasParticipant(p53, hospitalF). hasParticipant(q53, bobSmith). hasRole(q53, affiliatedWith). hasDeclaredType(r53, r5). hasCustodian(p53, r53). hasCustodian(q53, r53).
relationship(r54). hasParticipant(p54, hospitalF). hasParticipant(q54, jamesMcGill). hasRole(q54, affiliatedWith). hasDeclaredType(r54, r5). hasCustodian(p54, r54). hasCustodian(q54, r54).
%relationship(r55). hasParticipant(p55, hospitalF). hasParticipant(q55, generalPhys). hasRole(q55, affiliatedWith). hasDeclaredType(r55, r5). hasCustodian(p55, r55). hasCustodian(q55, r55).

% Supervision */
relationship(r56). hasParticipant(p56, elonMusk). hasParticipant(q56, charlieChaplin). hasRole(q56, supervises). hasDeclaredType(r56, r41). hasCustodian(p56, r56). hasCustodian(q56, r56).
relationship(r57). hasParticipant(p57, bobSmith). hasParticipant(q57, elonMusk). hasRole(q57, supervises). hasDeclaredType(r57, r41).  hasCustodian(p57, r57). hasCustodian(q57, r57).

% Consultations */
% G (Dave) */
relationship(r58). hasParticipant(p58, patientEve). hasParticipant(q58, consultG). hasRole(q58, involves). hasDeclaredType(r58, r2). hasCustodian(p58, r58). hasCustodian(q58, r58).
relationship(r59). hasParticipant(p59, jamesMcGill). hasParticipant(q59, consultG). hasRole(q59, isPerformedBy). hasDeclaredType(r59, r4). hasCustodian(p59, r59). hasCustodian(q59, r59).
% H (Bob) */
relationship(r60). hasParticipant(p60, patientEve). hasParticipant(q60, consultH). hasRole(q60, involves). hasDeclaredType(r60, r2). hasCustodian(p60, r60). hasCustodian(q60, r60).
relationship(r61). hasParticipant(p61, elonMusk). hasParticipant(q61, consultH). hasRole(q61, isPerformedBy). hasDeclaredType(r61, r4). hasCustodian(p61, r61). hasCustodian(q61, r61).
% I (Charlie - old) */
relationship(r62). hasParticipant(p62, patientEve). hasParticipant(q62, consultI). hasRole(q62, involves). hasDeclaredType(r62, r2). hasCustodian(p62, r62). hasCustodian(q62, r62).
relationship(r63). hasParticipant(p63, charlieChaplin). hasParticipant(q63, consultI). hasRole(q63, isPerformedBy). hasDeclaredType(r63, r4). hasCustodian(p63, r63). hasCustodian(q63, r63).
% T (Manouchehr) */
relationship(r72). hasParticipant(p72, patientEve). hasParticipant(q72, consultT). hasRole(q72, involves). hasDeclaredType(r72, r2). hasCustodian(p72, r72). hasCustodian(q72, r72).
relationship(r73). hasParticipant(p73, manoDelon). hasParticipant(q73, consultT). hasRole(q73, isPerformedBy). hasDeclaredType(r73, r4). hasCustodian(p73, r73). hasCustodian(q73, r73).
% Records */
relationship(r64). hasParticipant(p64, orthoRecJ). hasParticipant(q64, patientEve). hasRole(q64, includes). hasDeclaredType(r64, r1). hasCustodian(p64, r64). hasCustodian(q64, r64).
relationship(r65). hasParticipant(p65, generalRecK). hasParticipant(q65, patientEve). hasRole(q65, includes). hasDeclaredType(r65, r1). hasCustodian(p65, r65). hasCustodian(q65, r65).
relationship(r66). hasParticipant(p66, hivRecL). hasParticipant(q66, patientEve). hasRole(q66, includes). hasDeclaredType(r66, r1). hasCustodian(p66, r66). hasCustodian(q66, r66).

% Record-Consult Links */
relationship(r67). hasParticipant(p67, generalRecK). hasParticipant(q67, consultG). hasRole(q67, hasRecord). hasDeclaredType(r67, r75). hasCustodian(p67, r67). hasCustodian(q67, r67).
relationship(r68). hasParticipant(p68, orthoRecJ). hasParticipant(q68, consultH). hasRole(q68, hasRecord). hasDeclaredType(r68, r76). hasCustodian(p68, r68). hasCustodian(q68, r68).
relationship(r69). hasParticipant(p69, hivRecL). hasParticipant(q69, consultI). hasRole(q69, hasRecord). hasDeclaredType(r69, r77). hasCustodian(p69, r69). hasCustodian(q69, r69).
relationship(r74). hasParticipant(p74, generalRecT). hasParticipant(q74, consultT). hasRole(q74, hasRecord). hasDeclaredType(r74, r75). hasCustodian(p74, r74). hasCustodian(q74, r74).

% Creator */
relationship(r70). hasParticipant(p70, orthoRecJ). hasParticipant(q70, elonMusk). hasRole(q70, creatorOf). hasDeclaredType(r70, r26). hasCustodian(p70, r70). hasCustodian(q70, r70).
relationship(r78). hasParticipant(p78, generalRecT). hasParticipant(q78, manoDelon). hasRole(q78, creatorOf). hasDeclaredType(r78, r26). hasCustodian(p78, r78). hasCustodian(q78, r78).

% Consent */
relationship(r71). hasParticipant(p71, patientEve). hasParticipant(q71, jamesMcGill). hasRole(q71, hasConsentFrom). hasDeclaredType(r71, r21). hasCustodian(p71, r71). hasCustodian(q71, r71).

% start date attribute (keep same style as Bob)
attribute(startDateMia). hasCustodian(startDateMia, jordanDoletta). hasValue(startDateMia, 2025). hasDeclaredType(startDateMia, employingDate).
relationship(r99). hasParticipant(p99, hospitalF). hasParticipant(q99, jordanDoletta). hasRole(q99, affiliatedWith). hasDeclaredType(r99, r5). hasCustodian(p99, r99). hasCustodian(q99, r99).

relationship(r98). hasParticipant(p98, hospitalF). hasParticipant(q98, manoDelon). hasRole(q98, affiliatedWith). hasDeclaredType(r98, r5). hasCustodian(p98, r98). hasCustodian(q98, r98).

% ==================================================================================
%   PART 3: THE POLICIES (Access Rules)
%   Format: declared_policy(ID, Level, Policy, ScopeS, ScopeO, Action, Constraint)
%   ================================================================================== */

% O0: Ontology Level */
declared_policy(deny_10_view, o0, deny, pht, mrt, view, default_view_denial). %10 deny
declared_policy(deny_10_add,  o0, deny, pht, mrt, add,  default_add_denial). %10

% O1: Type Level */
declared_policy(grant_2, o1, grant, physician, medicalRecord, view, has_consent_from_patient).
declared_policy(grant_5, o1, grant, physician, medicalRecord, add,  matching_specialty_same_ontology).
declared_policy(grant_6, o1, grant, physician, medicalRecord, add,  same_hospital_with_patient).
declared_policy(grant_7, o1, grant, physician, medicalRecord, view, performed_consult_same_hospital).
declared_policy(grant_12,o1, grant, physician, generalRecord, view, always_true). %12
declared_policy(grant_4, o1, grant, physician, medicalRecord, view, consult_includes_record_from_2024).
declared_policy(grant_14, o1,grant, physician, medicalRecord, add,  emergency_consultation). %14

% O2: Role Level */
declared_policy(grant_3,     o2, grant, physician,         medicalRecord, view, supervisor_of_creator_can_view).
declared_policy(deny_1,  o2, deny,  trainee,           medicalRecord, add,  always_true). %deny 1
declared_policy(grant_11,    o2, grant, generalTrainee,    medicalRecord, add,  always_true). %11
declared_policy(deny_8,  o2, deny,  trainee,           medicalRecord, view, trainee_view_denied_if_old_consult).
declared_policy(grant_9,     o2, grant, physician,         medicalRecord, view, supervised_consult_chain_view).

% O3: Role Level */
declared_policy(deny_13, o3, deny, jordanDoletta, generalRecK, view, jordanDoletta_view_denied). %13 deny

% ==================================================================================
%   PART 4: CONSTRAINTS (Satisfies)
%   ================================================================================== */

% Always True */
satisfies(always_true, S, O) :- hasCustodian(S, _), hasCustodian(O, _).
satisfies(default_view_denial, S, O) :- hasCustodian(S, _), hasCustodian(O, _). % Simplified for this test */
satisfies(default_add_denial, S, O) :- hasCustodian(S, _), hasCustodian(O, _). % Simplified for this test */

% Grant 2: Consent */
satisfies(has_consent_from_patient, S, O) :-
    isa(O, medicalRecord),
    triple(P, includes, O), isa(P, patient),
    triple(S, hasConsentFrom, P).

% Grant 6: Same Hospital */
satisfies(same_hospital_with_patient, S, O) :-
    isa(S, physician),
    isa(O, medicalRecord),
    triple(P, includes, O), isa(P, patient),
    triple(S, affiliatedWith, H), isa(H, hospital),
    triple(P, isEnrolledIn, H).

% Grant 5: Matching Specialty */
satisfies(matching_specialty_same_ontology, S, O) :-
    isa(S, physician),
    isa(O, medicalRecord),
    phys_specialty(S, Spec),
    rec_category(O, Spec),
    hasCustodian(S, ONT), hasCustodian(O, ONT).

% Helpers for Specialty */
phys_specialty(S, orthopedic) :- isa(S, orthopedic).
phys_specialty(S, general) :- isa(S, general).
phys_specialty(S, hiv) :- isa(S, hiv).
rec_category(O, orthopedic) :- isa(O, orthopedicRecord).
rec_category(O, general)    :- isa(O, generalRecord).
rec_category(O, hiv)        :- isa(O, hIVRecord).

% Grant 7: Performed Consult Same Hospital */
satisfies(performed_consult_same_hospital, S, O) :-
    isa(O, medicalRecord),
    isa(P, patient),
    isa(H, hospital),
    isa(C, consultation),
    triple(C, hasRecord, O),
    triple(S, affiliatedWith, H),
    triple(P, isEnrolledIn, H),
    triple(C, isPerformedBy, S),
    triple(C, involves, P).

% Grant 4: Recent Consultation */
satisfies(consult_includes_record_from_2024, S, O) :-
    isa(O, medicalRecord),
    triple(P, includes, O), isa(P, patient),
    triple(C, isPerformedBy, S),
    triple(C, involves, P),
    triple(C, hasRecord, O),
    has_attribute(Attr, C, V), isa(Attr, consultationDate),
    greater_than_or_equal(V, 2024).

greater_than_or_equal(2025, 2024).
greater_than_or_equal(2024, 2024).

% Grant 3: Supervisor of Creator */
satisfies(supervisor_of_creator_can_view, S, O) :-
    isa(O, medicalRecord),
    triple(Creator, creatorOf, O),
    is_supervisor(S, Creator).

is_supervisor(X, Y) :- triple(X, supervises, Y).
is_supervisor(X, Y) :- is_supervisor(X, Z), is_supervisor(Z, Y).

% Prohibit 8: Trainee Old Consult */
satisfies(trainee_view_denied_if_old_consult, S, O) :-
    isa(S, trainee),
    isa(O, medicalRecord),
    triple(P, includes, O), isa(P, patient),
    triple(C, involves, P),
    triple(C, hasRecord, O),
    has_attribute(AC, C, ConsultYear), isa(AC, consultationDate),
    has_attribute(AS, S, StartYear), isa(AS, startingDate),
    older_than_4_years(ConsultYear, StartYear).

older_than_4_years(2020, 2025).

% Grant 9: Supervised Consult Chain */
satisfies(supervised_consult_chain_view, S, O) :-
    isa(S, physician),
    isa(O, medicalRecord),
    isa(P, patient),
    isa(CNEW, consultation),
    triple(CNEW, isPerformedBy, S),
    triple(CNEW, involves, P),
    triple(CNEW, hasRecord, O),
    isa(SUP, physician),
    isa(C, consultation),
    is_supervisor(SUP, S),
    triple(C, isPerformedBy, SUP),
    triple(C, involves, P).

% Grant 10: jordanDoletta_add_denied */
satisfies(jordanDoletta_view_denied, jordanDoletta, generalRecK) :-
    isa(jordanDoletta, physician),
    isa(generalRecK, medicalRecord).

% Grant 11:emergency_consultation */
satisfies(emergency_consultation, S, O) :-
    isa(S, physician),
    isa(O, medicalRecord),
    triple(C, isPerformedBy, S),
    triple(C, involves, P), isa(P, patient),
    triple(C, hasRecord, O),
    isa(A, ConsultationEmergencyMode),
    has_attribute(A, C, true).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% METRICS LAYER (no aggregates; count in Java)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Decide level(s): any level with at least one most-specialized applicable rule
deciding_level(S,O,A,L) :-
  most_specialized_applicable_rule_at_level(L, _, S, O, A).

% Applicable rules at a given level (A0)
applicable_at_level(S,O,A,L,RuleId,Pol) :-
  applicable_policy(RuleId, L, Pol, S, O, A).

% Winners at a given level (A)
winner_at_level(S,O,A,L,Pol) :-
  most_specialized_applicable_rule_at_level(L, Pol, S, O, A).

% Shadowed rules at a given level (A0 \ A)
shadowed_at_level(S,O,A,L,RuleId) :-
  is_shadowed(RuleId, L, S, O, A).

% Preempted levels (mention depth proxy)
preempted_level(S,O,A,L) :-
  is_preempted(L, S, O, A).

% Conflict: both grant and deny survive at the deciding level
true_conflict(S,O,A) :-
  deciding_level(S,O,A,L),
  most_specialized_applicable_rule_at_level(L, grant, S, O, A),
  most_specialized_applicable_rule_at_level(L, deny,  S, O, A).
