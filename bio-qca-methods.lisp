;;; ------------------------------------------------------------
;;; Bio methods defining the goal hierarchy and exec behavior for
;;; qualitative causal agent (QCA)

(:in-context exec-methods)


;; ------------------------------
;; FIND-QCA-PATH
;; ------------------------------

(kbop:method
 :matches ((evaluate ?goal))
 :pre ((some (is-ask-what ONT::STATUS ?goal ?what)
             (is-ask-what ONT::METHOD ?goal ?what))
       (suchthat ?what ?st)
       (instance-of ?st ?type)
       (:set-member ?type (set-fn ONT::ACTIVATE ONT::MODULATE))

       (affected ?st ?affected)
       (some (dbname ?affected ?target))
       (get-term-xml ?affected ?affected-xml)

       (agent ?st ?agent)
       (some (dbname ?agent ?source))
       (get-term-xml ?agent ?source-xml))
 :on-ready ((:note "ACCEPTABLE" ?what)
            (:store (evaluate-result ?goal acceptable)))
 :result success)


;; FUNDA: First ask for a direct causal path

 (kbop:method
  :matches ((what-next ?goal ?reply-id))
  :pre ((some (is-ask-what ONT::STATUS ?goal ?what)
              (is-ask-what ONT::METHOD ?goal ?what))
        (suchthat ?what ?st)
        (instance-of ?st ?type)
        (:set-member ?type (set-fn ONT::ACTIVATE ONT::MODULATE))

        (affected ?st ?affected)
        (some (dbname ?affected ?target))
        (get-term-xml ?affected ?affected-xml)

        (agent ?st ?agent)
        (some (dbname ?agent ?source))
        (get-term-xml ?agent ?source-xml))
  :on-ready ((:gentemp ?query-id "causality-")
             (:store (query ?query-id (find-causal-path
                                       :target ?affected-xml
                                       :source ?source-xml)))
                                       (:say "causal-path query?")
             (:dbug "Ask CausalityAgent if FIND-CAUSAL-PATH"
                    "for affected" ?affected ?target)
             (:subgoal (ask-bioagents ?query-id ?goal))
             (:subgoal (expand-query-result ?query-id ?goal ?reply-id ?affected-xml ?source-xml))))


;; Give an NL explanation if there is one
 (kbop:method
  :matches ((expand-query-result ?query-id ?goal ?reply-id ?affected-xml ?source-xml))
  :pre ((answer ?query-id ?ans)
        (paths ?ans ?paths))
  :on-ready (;; Get the NLG explanation.
             (:gentemp ?nlg-id "causality-nlg-")
             (:subgoal (get-bio-nlg-text ?goal ?paths ?nlg-id))

             ;; Store a useful version of it.
             (:subgoal (store-nlg-utterance ?nlg-id ?ans))
             (:subgoal (report-answer ?query-id ?goal ?reply-id))))


;;Or ask QCA
 (kbop:method
  :matches ((expand-query-result ?query-id ?goal ?reply-id ?affected-xml ?source-xml))
  :pre ((answer ?query-id (list-fn failure no_path_found)))
  :on-ready (;; No path was found.
             (:say "CausalityAgent could not find a causal relationship. QCA is looking at other sources now.")
             (:dbug "CausalityAgent could not find a causal relationship.")
            ;; (:subgoal (report-answer ?query-id ?goal ?reply-id))
               (:subgoal (ask-qca  ?affected-xml ?source-xml ?goal ?reply-id ))))

;;QCA Methods

(kbop:method
 :matches ((ask-qca ?affected-xml ?source-xml ?goal ?reply-id ))
 :on-ready ((:gentemp ?query-id "qca-")
            (:store (query ?query-id (find-qca-path
                                      :target ?affected-xml
                                      :source ?source-xml)))
            (:dbug "Ask QCA if FIND-QCA-PATH"
                   "for affected" ?affected ?target)
            (:subgoal (ask-bioagents ?query-id ?goal))
            (:subgoal (retrieve-nl-explanation ?query-id ?goal ?reply-id))))

(kbop:method
 :matches ((retrieve-nl-explanation ?query-id ?goal ?reply-id))
 :pre ((answer ?query-id ?ans)
       (paths ?ans ?paths))
 :on-ready (;; Get the NLG explanation.
            (:gentemp ?nlg-id "qca-nlg-")
            (:subgoal (get-bio-nlg-text ?goal ?paths ?nlg-id))
            ;; Store a useful version of it.
            (:subgoal (store-nlg-utterance ?nlg-id ?ans))
            (:subgoal (report-answer ?query-id ?goal ?reply-id))))

(kbop:method
 :matches ((retrieve-nl-explanation ?query-id ?goal ?reply-id))
 :pre ((answer ?query-id (list-fn failure no_path_found)))
 :on-ready (;; No path was found.
            (:dbug "QCA could not find a path.")
            (:subgoal (report-answer ?query-id ?goal ?reply-id))))

(kbop:method
 :matches ((retrieve-nl-explanation ?query-id ?goal ?reply-id))
 :pre ((answer ?query-id (list-fn failure)))
 :on-ready (;; No path was found.
            (:dbug "QCA could not find a path.")
            (:subgoal (report-answer ?query-id ?goal ?reply-id))))

(kbop:method
 :matches ((store-nlg-utterance ?nlg-id ?target))
 :pre ((answer ?nlg-id ?ans)
       (nl ?ans ?nls))
 :on-ready (;; Here we are storing the list of NL utterances. We
            ;; *could* assemble them into a single string, like the
            ;; bio-model-building methods do. But it's probably better
            ;; not to, since the generate code should really be the
            ;; one doing smart things.
            (:store (nl ?target ?nls)))
 :result success)
