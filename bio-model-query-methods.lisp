;;; ------------------------------------------------------------
;;; Bio methods that define the goal hierarchy and executive
;;; behavior for the SPG w/r/t model queries.
;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; High-level CPSA goal

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-ask-if ?type ?goal ?what)
       ;; [jrye:20170324.1125CST] I found these types in the
       ;; bio-model-query-rules in the query-parameters horn
       ;; clauses. I don't know if these are complete. I also don't
       ;; know if they are all necessary.
       (:set-member ?type (set-fn ONT::DISAPPEAR ONT::DEPLETE
                                  ONT::ACTIVITY-ONGOING
                                  ONT::HAVE-PROPERTY
                                  ONT::BIND))
       (find-create-goal ?goal ?create-goal)
       (model-id ?create-goal ?model))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-ask-if ?type ?goal ?what)
       (:set-member ?type (set-fn ONT::DISAPPEAR ONT::DEPLETE
                                  ONT::ACTIVITY-ONGOING
                                  ONT::HAVE-PROPERTY
                                  ONT::BIND))
       (find-create-goal ?goal ?create-goal)
       (model-id ?create-goal ?model))
 :on-ready ((:gentemp ?query-id "model-query-")
            (:subgoal (prepare-model-query ?query-id ?goal ?model))
            (:subgoal (perform-model-query ?query-id ?goal ?reply-id))))

;;; ------------------------------------------------------------
;;; Preparing the query to the TRA

;;; If something failed when trying to create the query, our fallback
;;; is just to store a failure indication to be reported later.
(kbop:method
 :matches ((prepare-model-query ?query-id ?goal ?model-id))
 :priority -1
 :on-ready ((:note "Cannot create model query"))
 :result success)

;;; Our highest priority goal is to actually assemble the query.
(kbop:method
 :matches ((prepare-model-query ?query-id ?goal ?model-id))
 :priority 2
 :pre (;; Get the basic query parameters.
       (goal-query-parameters ?goal ?term-of-quantity ?frequency-string ?value-string)
       ;; And get any condition terms.
       (:aggregate
        ?cond-terms ?cond-term
        (query ?goal ?query)
        (condition ?query ?cond-term)))
 :on-ready (;; First build the central term xml.
            (:note "term of quantity" ?term-of-quantity)
            (:subgoal (retrieve-ekb-xml ?term-of-quantity ?term-of-quantity))

            ;; Next build the XML for any condition terms.
            (:note "conditions" ?cond-terms)
            (:foreach ?cond-term ?cond-terms
                      (:subgoal (prepare-cond-block-entry ?cond-term)))

            ;; Now store all this stuff in the query that we'll send.
            (:subgoal (format-and-store-model-query
                       ?query-id
                       ?term-of-quantity ?frequency-string ?value-string ?model-id
                       ?cond-terms))))

(kbop:method
 :matches ((prepare-cond-block-entry ?cond-term))
 :on-ready ((:subgoal (retrieve-cond-xml ?cond-term))
            (:subgoal (store-cond-block-entry ?cond-term))))

(kbop:method
 :matches ((retrieve-cond-xml ?cond-id))
 :pre ((ground ?cond-id ?ground-id)
       (affected ?ground-id ?affected-id)
       (figure ?affected-id ?term-id))
 :on-ready ((:subgoal (retrieve-ekb-xml ?term-id ?cond-id))))

(kbop:method
 :matches ((store-cond-block-entry ?cond-term))
 ;; Note: it looks like the ?about-term isn't referenced. Do we need
 ;; to retrieve it?
 :pre ((goal-query-condition ?cond-term ?about-term
                             ?cond-type-string
                             ?cond-value ?cond-quantity-string)
       (ekb-xml ?cond-term ?cond-ekb-xml)
       (:assign ?cond-block-entry (:type ?cond-type-string :value ?cond-value
                                         :quantity
                                         (:type ?cond-quantity-string
                                                :entity (:description ?cond-ekb-xml)))))
 :on-ready ((:store (cond-block-entry ?cond-term ?cond-block-entry)))
 :result success)

(kbop:method
 :matches ((format-and-store-model-query
            ?query-id
            ?term-of-quantity ?frequency-string ?value-string ?model-id
            ?cond-terms))
 :pre (;; We have the EKB for the main term.
       (ekb-xml ?term-of-quantity ?the-ekb-xml)

       ;; And there are no conditions.
       (:empty ?cond-terms)

       (get-satisfies-pattern-query
        ?frequency-string ?the-ekb-xml ?value-string ?model-id ?the-query))
 :on-ready ((:dbug "Built" ?frequency-string
                   "with value" ?value-string
                   "query about " ?term-of-quantity
                   "for model" ?model-id
                   "with no conditions")
            ;; (:dbug "The query is" ?the-query)
            (:store (query ?query-id ?the-query)))
 :result success)

(kbop:method
 :matches ((format-and-store-model-query
            ?query-id
            ?term-of-quantity ?frequency-string ?value-string ?model-id
            ?cond-terms))
 :pre (;; We have the EKB for the main term.
       (ekb-xml ?term-of-quantity ?the-ekb-xml)

       ;; Assemble the individual conds for each of the terms.
       (:aggregate
        ?cond-block-entries ?cond-block-entry
        (:set-member ?cond-term ?cond-terms)
        (cond-block-entry ?cond-term ?cond-block-entry))

       ;; Make sure we have *all* the conds.
       (:cardinality ?cond-terms ?num-cond-terms)
       (:cardinality ?cond-block-entries ?num-conds)
       (:= ?num-cond-terms ?num-conds)
       (:< 0 ?num-cond-terms)

       ;; The condition block is the list of conds, which we formatted
       ;; in the aggregate expression above.
       (:cdr ?condition-block ?cond-block-entries)

       ;; Finally, mash it all together into the query.
       (get-satisfies-pattern-query-cond
        ?frequency-string ?the-ekb-xml ?value-string ?model-id ?the-query ?condition-block))
 :on-ready ((:dbug "Built" ?frequency-string
                   "with value" ?value-string
                   "query about " ?term-of-quantity
                   "for model" ?model-id
                   "with conditions" ?condition-block)
            ;; (:dbug "The query is" ?the-query)
            (:store (query ?query-id ?the-query)))
 :result success)

;;; ------------------------------------------------------------
;;; Send the query and deal with the answer

;;; If we failed to prepare the query, we will just report that
;;; instead of making a round-trip to the TRA.
(kbop:method
 :matches ((perform-model-query ?query-id ?goal ?reply-id))
 :priority 2
 :pre ((:uninferrable (query ?query-id ?query)))
 :on-ready ((:note "no query")
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON CANT-MAKE-MODEL-QUERY))))
 :result success)

(kbop:method
 :matches ((perform-model-query ?query-id ?goal ?reply-id))
 :priority 1
 :on-ready ((:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (report-answer ?query-id ?goal ?reply-id))))

