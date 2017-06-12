;;; ------------------------------------------------------------
;;; Bio methods defining the goal hierarchy and exec behavior for
;;; phosphoproteomics causality agent (PCA)

(:in-context exec-methods)



;; ------------------------------
;; IS-CAUSALITY-TARGET
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::PHOSPHORYLATION ?goal ?what)
       (agent ?what ?agent)
       (:uninferrable (instance-of ?agent ONT::GENE-PROTEIN))
       )
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::PHOSPHORYLATION ?goal ?what)
       (agent ?what ?agent)
       (:uninferrable (instance-of ?agent ONT::GENE-PROTEIN))
       (get-term-xml ?agent ?agent-xml)
       (affected ?what ?affected)
       (get-term-xml ?affected ?affected-xml))
 :on-ready ((:gentemp ?query-id "causality-query-")
            (:store (query ?query-id (is-causality-target
                                      :causality ?agent-xml
                                      :target ?affected-xml)))
            (:dbug "Ask CAUSALITY if IS-CAUSALITY-TARGET for agent" ?agent
                   "and affected" ?affected)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (retrieve-nl-explanation ?query-id ?goal ?reply-id))
            (:subgoal (ask-correlation ?affected-xml ?goal ?reply-id))))

;; ------------------------------
;; FIND-CAUSALITY-SOURCE
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::PROTEIN ?goal ?what)
       (affected-by-what ?what ?affected))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)




(kbop:method
 :matches ((ask-correlation ?affected-xml ?goal ?reply-id))

 :on-ready ((:gentemp ?query-id "correlation-query-")
            (:store (query ?query-id (dataset-correlated-entity
                                                              :source ?affected-xml)))
            (:subgoal (ask-bioagents ?query-id ?goal))
            ;;(:say "Do you have any causal explanation for this?")
            ))



(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::GENE ?goal ?what)
       (affected-by-what ?what ?affected)
       (get-query-type ?what ?affected ?query-type)
       (get-term-xml ?affected ?affected-xml)
       )
 :on-ready ((:gentemp ?query-id "causality-query-")
            (:store (query ?query-id (find-causality-source
                                      :source ?affected-xml :type ?query-type)))
            (:store (source ?query-id ?affected))
            (:dbug "Ask CAUSALITY to FIND-CAUSALITY-SOURCE"
                   "for affected" ?affected)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (retrieve-nl-explanation ?query-id ?goal ?reply-id))
            ;;Create a new query
            (:subgoal (ask-correlation ?affected-xml ?goal ?reply-id))
           ;; (:say "Do you have any causal explanation for this?")
            ))


;; ------------------------------
;; FIND-CAUSALITY-TARGET
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-what ONT::GENE ?goal ?what))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-what ONT::GENE ?goal ?what)
       (agent ?query ?agent)
       (get-term-xml ?agent ?agent-xml)
       (some (instance-of ?query ONT::PHOSPHORYLATION)
       (instance-of ?query ONT::DEPHOSPHORYLATION)
       (instance-of ?query ONT::INCREASE)
       (instance-of ?query ONT::DECREASE)
       (instance-of ?query ONT::ACTIVATE)
       (instance-of ?query ONT::INHIBIT)
       (instance-of ?query ONT::MODULATE)
       )
       (affected ?query ?what)
       (get-query-type ?agent ?what ?query-type)
       )
 :on-ready ((:gentemp ?query-id "causality-query-")
            (:store (query ?query-id (find-causality-target
                                      :target ?agent-xml :type ?query-type)))
            (:store (target ?query-id ?agent))
            (:dbug "Ask CAUSALITY to FIND-CAUSALITY-TARGET"
                   "for agent" ?agent)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (retrieve-nl-explanation ?query-id ?goal ?reply-id))))



;;; ------------------------------------------------------------
;;; Some rules

(:in-context collab-context)

(<< (affected-by-what ?what ?affected)
    (agent ?query ?what)
    (some (instance-of ?query ONT::PHOSPHORYLATION)
    (instance-of ?query ONT::DEPHOSPHORYLATION)
    (instance-of ?query ONT::INCREASE)
    (instance-of ?query ONT::DECREASE)
    (instance-of ?query ONT::ACTIVATE)
    (instance-of ?query ONT::INHIBIT)
    (instance-of ?query ONT::MODULATE))
    (affected ?query ?affected))


(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::INCREASE)
    (affected ?query ?affected)
    (:assign ?query-type "increase"))

(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::DECREASE)
    (affected ?query ?affected)
    (:assign ?query-type "decrease"))


(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::INHIBIT)
    (affected ?query ?affected)
    (:assign ?query-type "inhibit"))

(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::ACTIVATE)
    (affected ?query ?affected)
    (:assign ?query-type "activate"))

(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::PHOSPHORYLATION)
    (affected ?query ?affected)
    (:assign ?query-type "phosphorylation"))

(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::DEPHOSPHORYLATION)
    (affected ?query ?affected)
    (:assign ?query-type "dephosphorylation"))

(<< (get-query-type ?what ?affected ?query-type)
    (agent ?query ?what)
    (instance-of ?query ONT::MODULATE)
    (affected ?query ?affected)
    (:assign ?query-type "modulate"))


(<< (gene-for-what ?what ?gene)
    (suchthat ?what ?st)
    (neutral1 ?st ?tf)
    (or (assoc-with ?tf ?gene)
        (:assign ?gene ?tf))
    (instance-of ?gene ont::gene-protein))

(<< (gene-for-what ?what ?gene)
    (suchthat ?what ?st)
    (affected ?st ?gene)
    (instance-of ?gene ont::gene-protein))

