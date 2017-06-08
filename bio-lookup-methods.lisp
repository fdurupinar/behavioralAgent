;;; ------------------------------------------------------------
;;; Bio methods that define the goal hierarchy and executive
;;; behavior for the SPG w/r/t bioagent lookup queries.
;;;
(:in-context exec-methods)

;; --------------------------------
;; DETERMINE TREATMENT
;; --------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-determine-goal ?goal))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-determine-goal ?goal))
 :on-ready ((:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal
                                                      :STATUS ont::waiting-for-user))))
 :result success)

;; --------------------------------
;; IDENTIFY MEDICATION (targeting disease)
;; --------------------------------
;; This is the first question in the March 2016 demo -- Is there a
;; drug to treat...? We want to send a find-treatment message to DTDA
;; at this point.

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::MEDICATION ?goal ?what)
       ;; (suchthat ?wti ?st)
       ;; (instance-of-some ?st (set-fn ont::use ont::assoc-with))
       (get-disease-of-interest ?goal ?did)
       (:uninferrable (get-gene-target ?what ?gid)))
 :on-ready ((:note "ACCEPTABLE, disease:" ?did)
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::MEDICATION ?goal ?what)
       ;; (suchthat ?wti ?st)
       ;; (instance-of-some ?st (set-fn ont::use ont::assoc-with))
       (get-disease-of-interest ?goal ?did)
       (:uninferrable (get-gene-target ?what ?gid)))
 :on-ready ((:subgoal (identify medication use ?did ?what ?goal ?reply-id))))

(kbop:method
 :matches ((identify medication use ?target ?what ?goal ?reply-id))
 :pre ((:uninferrable (instance-of ?target ont::gene))
       (some (dbname ?target ?disease)
             (instance-of ?target ?disease))
       (get-term-xml ?target ?ekb-xml))
 :on-ready ((:gentemp ?query-id "bio-lookup-")
            (:store (query ?query-id (find-treatment :disease ?ekb-xml)))
            (:store (target ?query-id ?disease))
            (:dbug "Ask DTDA to FIND-TREATMENT for" ?target
                   "which is of type" ?disease)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

;; --------------------------------
;; IDENTIFY PROTEIN
;; --------------------------------
;; This is the second question in the March 2016 demo -- Is there a
;; protein affecting pancreatic cancer...? We want to send a
;; find-disease-targets message to DTDA at this point.

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (get-result-for-protein ?what ?rid))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (get-result-for-protein ?what ?rid))
 :on-ready ((:subgoal (identify protein cause ?rid ?what ?goal ?reply-id))))

(kbop:method
 :matches ((identify protein cause ?result ?what ?goal ?reply-id))
 :pre ((affected-by-protein ?result ?target)
       (some (dbname ?target ?disease)
             (instance-of ?target ?disease))
       (get-term-xml ?target ?ekb-xml))
 :on-ready ((:gentemp ?query-id "bio-lookup-")
            (:store (query ?query-id (find-disease-targets :disease ?ekb-xml)))
            (:store (target ?query-id ?disease))
            (:dbug "Ask DTDA to FIND-DISEASE-TARGETS for" ?target
                   "which is of type" ?disease)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))
            ))

;; --------------------------------
;; IDENTIFY MEDICATION (targeting gene)
;; --------------------------------
;; This is the third question in the March 2016 demo -- Is there a
;; drug targeting KRAS...? We want to send a find-target-drug message
;; to DTDA at this point.

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::MEDICATION ?goal ?what)
       ;; (suchthat ?wti ?st)
       ;; (instance-of-some ?st (set-fn ont::use ont::assoc-with))
       (get-gene-target ?what ?gid))
 :on-ready ((:note "ACCEPTABLE, gene:" ?gid)
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::MEDICATION ?goal ?what)
       ;; (suchthat ?wti ?st)
       ;; (instance-of-some ?st (set-fn ont::use ont::assoc-with))
       (get-gene-target ?what ?gid))
 :on-ready ((:subgoal (identify medication modulate ?gid ?what ?goal ?reply-id))))

(kbop:method
 :matches ((identify medication modulate ?target ?what ?goal ?reply-id))
 :pre ((some (dbname ?target ?gene)
             (instance-of ?target ?gene))
       (get-term-xml ?target ?ekb-xml))
 :on-ready ((:gentemp ?query-id "bio-lookup-")
            (:store (query ?query-id (find-target-drug :target ?ekb-xml)))
            (:store (target ?query-id ?gene))
            (:store (target-ekb ?query-id ?ekb-xml))
            (:store (what ?goal ?what))
            (:dbug "Ask DTDA to FIND-TARGET-DRUG for" ?target
                   "which is of type" ?gene)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (check-dtda-answer ?goal ?query-id ?reply-id))
            ))

;; This is the case where there are no drugs found for the target
;; in this case we try to look for upstream targets in the model
(kbop:method
 :matches ((check-dtda-answer ?goal ?query-id ?reply-id))
 :pre (
    (answer ?query-id ?answer)
    (find-model-id ?goal ?model-id)
    (drugs ?answer ?drugs)
    (:same ?drugs none)
    (target-ekb ?query-id ?target-ekb)
    )
   :on-ready (
    (:gentemp ?mra-query-id "bio-lookup-")
    (:store (query ?mra-query-id (model-get-upstream :target ?target-ekb :model-id ?model-id)))
    (:subgoal (ask-bioagents ?mra-query-id ?goal))
    (:say "I couldn't find a drug but I'll look for ones that target upstream proteins in our model.")
    (:subgoal (check-mra-upstream-answer ?goal ?query-id ?mra-query-id ?reply-id))
    )
 )

;; This is the case where there are no drugs found for the target
;; and there's no model being built so we just report an answer
(kbop:method
 :matches ((check-dtda-answer ?goal ?query-id ?reply-id))
 :pre (
    (answer ?query-id ?answer)
    (:uninferrable (find-model-id ?goal ?model-id))
    (what ?goal ?what)
    )
   :on-ready (
    (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))
    )
 )

;; This is the case where there is a list of drugs from the DTDA
;; so we just report those
 (kbop:method
  :matches ((check-dtda-answer ?goal ?query-id ?reply-id))
  :pre (
     (answer ?query-id ?answer)
     (drugs ?answer ?drugs)
     (:different ?drugs none)
     (what ?goal ?what)
     )
  :on-ready (
     (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))
     )
  )

;; Having asked the MRA for upstream proteins, we now need to send another query
;; to the DTDA with the first upstream protein.
  (kbop:method
   :matches ((check-mra-upstream-answer ?goal ?query-id ?mra-query-id ?reply-id))
   :priority 1
   :pre (
      (answer ?mra-query-id ?answer)
      (upstream ?answer ?upstreamls)
      (:aggregatep ?upstreamls)
      (:cdr ?x ?upstreamls)
      (:car ?upstream ?x)
      (upstream-names ?answer ?upstream-namesls)
      (:cdr ?y ?upstream-namesls)
      (:car ?upstream-name ?y)
      (what ?goal ?what)
      (:stormat ?utterance "I'm looking for drugs for ~a" (?upstream-name))
      )
   :on-ready (
      (:gentemp ?dtda-query-id "bio-lookup-")
      (:store (query ?dtda-query-id (find-target-drug :target ?upstream)))
      (:subgoal (ask-bioagents ?dtda-query-id ?goal))
      (:say ?utterance)
      (:subgoal (report-answer ?dtda-query-id ?what ?goal ?reply-id))
      )
   )

(kbop:method
 :matches ((check-mra-upstream-answer ?goal ?query-id ?mra-query-id ?reply-id))
 :priority 2
 :pre ((answer ?mra-query-id ?answer)
       (upstream ?answer NONE)
       (:stormat ?utterance "I can't find any upstream proteins to check.")
       (what ?goal ?what))
 :on-ready ((:say ?utterance)
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id)))
 :result success)

;; IS-DRUG-TARGET requests

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((some
        (is-ask-if ONT::MODULATE ?goal ?what)
        (is-ask-if ONT::INHIBIT ?goal ?what))
        (agent ?what ?agent)
        (instance-of ?agent ?agent-type)
        (:sub-category ONT::PHARMACOLOGIC-SUBSTANCE ?agent-type)
       )
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((some
        (is-ask-if ONT::MODULATE ?goal ?what)
        (is-ask-if ONT::INHIBIT ?goal ?what))
       (agent ?what ?agent)
       (instance-of ?agent ?agent-type)
       (:sub-category ONT::PHARMACOLOGIC-SUBSTANCE ?agent-type)
       (get-term-xml ?agent ?agent-xml)
       (affected ?what ?affected)
       (get-term-xml ?affected ?affected-xml))
 :on-ready ((:gentemp ?query-id "dtda-query-")
            (:store (query ?query-id (is-drug-target
                                      :drug ?agent-xml
                                      :target ?affected-xml)))
            (:dbug "Ask DTDA if IS-DRUG-TARGET for agent" ?agent
                   "and affected" ?affected)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?what ?goal ?reply-id))))

(kbop:method
 :matches ((evaluate ?goal))
 :pre (
    (is-ask-what ONT::MEDICATION ?goal ?what)
    (suchthat ?what ?reln)
    (ground ?reln ?target)
    (instance-of ?target ?target-type)
    (:set-member ?target-type (set-fn ONT::GENE-PROTEIN ONT::GENE ONT::PROTEIN ONT::PROTEIN-FAMILY))
    )
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre (
    (is-ask-what ONT::MEDICATION ?goal ?what)
    (suchthat ?what ?reln)
    (ground ?reln ?target)
    (instance-of ?target ?target-type)
    (:set-member ?target-type (set-fn ONT::GENE-PROTEIN ONT::GENE ONT::PROTEIN ONT::PROTEIN-FAMILY))
    )
 :on-ready ((:gentemp ?query-id "dtda-query-")
            (:subgoal (identify medication modulate ?target ?what ?goal ?reply-id))))

(kbop:method
 :matches ((evaluate ?goal))
 :pre (
    (is-ask-what ONT::CHEMICAL ?goal ?what)
    ;;(dbname ?what CHEBI:35222)
    (dbname ?what "inhibitor")
    (mod ?what ?reln)
    (ground ?reln ?target)
    (instance-of ?target ?target-type)
    (:set-member ?target-type (set-fn ONT::GENE-PROTEIN ONT::GENE ONT::PROTEIN ONT::PROTEIN-FAMILY))
    )
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre (
    (is-ask-what ONT::CHEMICAL ?goal ?what)
    (mod ?what ?reln)
    ;;(db-term-id ?what CHEBI:35222)
    (dbname ?what "inhibitor")
    (ground ?reln ?target)
    (instance-of ?target ?target-type)
    (:set-member ?target-type (set-fn ONT::GENE-PROTEIN ONT::GENE ONT::PROTEIN ONT::PROTEIN-FAMILY))
    )
 :on-ready ((:gentemp ?query-id "dtda-query-")
            (:subgoal (identify medication modulate ?target ?what ?goal ?reply-id))))


(kbop:method
 :matches ((evaluate ?goal))
 :pre (
    (is-ask-if ONT::BE ?goal ?what)
    (neutral1 ?what ?inhib)
    ;;(dbname ?what CHEBI:35222)
    (dbname ?inhib "inhibitor")
    (mod ?inhib ?reln)
    (ground ?reln ?target)
    (instance-of ?target ?target-type)
    (:set-member ?target-type (set-fn ONT::GENE-PROTEIN ONT::GENE ONT::PROTEIN ONT::PROTEIN-FAMILY))
    )
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre (
    (is-ask-if ONT::BE ?goal ?what)
    (neutral1 ?what ?inhib)
    (mod ?inhib ?reln)
    ;;(db-term-id ?what CHEBI:35222)
    (dbname ?inhib "inhibitor")
    (ground ?reln ?target)
    (instance-of ?target ?target-type)
    (:set-member ?target-type (set-fn ONT::GENE-PROTEIN ONT::GENE ONT::PROTEIN ONT::PROTEIN-FAMILY))
    )
 :on-ready ((:gentemp ?query-id "dtda-query-")
            (:subgoal (identify medication modulate ?target ?inhib ?goal ?reply-id))))

