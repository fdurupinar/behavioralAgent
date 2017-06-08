;;; ------------------------------------------------------------
;;; Bio methods that define the goal hierarchy and executive
;;; behavior for the SPG w/r/t handling bioagents.
;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; Manage round-trip messaging with bioagents.
;;;
;;; For many things in the bio system, we want to pose a query to the
;;; bioagents. Here we provide the pieces to send the request and
;;; handle the response. Separately, when we get a WHAT-NEXT request from the
;;; CPSA, we will interpret and report the result.

(kbop:method
 :matches ((ask-bioagents ?query-id ?goal))
 :pre ((:uninferrable (query ?query-id ?query)))
 :on-ready ((:note "no query"))
 :result failure)

(kbop:method
 :matches ((ask-bioagents ?query-id ?goal))
 :pre ((query ?query-id ?query))
 :on-ready ((:note ?query)
            (:subgoal (send-message ?query ?query-id))
            (:subgoal (handle-response ?query-id))))

(kbop:method
 :matches ((send-message ?query-content ?reply-id))
 :on-ready ((:dbug "Sending message" ?query-content)
            ;; (:say "Standby, asking bioagents, this might take a few moments.")
            (:send-trips-msg
             (request :content ?query-content
                      :reply-with ?reply-id)))
 :result success)

(kbop:method
 :matches ((handle-response ?reply-id))
 :pre ((answer ?reply-id ?reply-content))
 :on-ready ((:dbug "Received reply from bioagents with id" ?reply-id
                   "and content" ?reply-content))
 :result success)

;;; ------------------------------------------------------------
;;; Get natural language explanations for things.

(kbop:method
 :matches ((get-bio-nlg-text ?main-goal ?statement-list ?nlg-id))
 :priority 1
 :pre ((:uninferrable (some (:symbolp ?statement-list)
                            (:stringp ?statement-list)))
       (:cardinality ?statement-list ?size)
       (:< 0 ?size)
       ;; FIXME But what should happen if there are more than one?
       (:elt-at ?statement-list 0 ?statements))
 :on-ready ((:store (query ?nlg-id
                           (INDRA-TO-NL :statements ?statements)))
            (:subgoal (ask-bioagents ?nlg-id ?main-goal))))

(kbop:method
 :matches ((get-bio-nlg-text ?main-goal ?statements ?nlg-id))
 :priority -1
 :on-ready ((:store (query ?nlg-id
                           (INDRA-TO-NL :statements ?statements)))
            (:subgoal (ask-bioagents ?nlg-id ?main-goal))))

;;; ------------------------------------------------------------
;;; Get EKB XML for things.

(kbop:method
 :matches ((retrieve-ekb-xml ?term-id-or-ids ?result-id))
 :on-ready ((:gentemp ?ekb-id "ekb-")
            (:store (ekb-id ?result-id ?ekb-id))
            (:get-ekb-xml ?ekb-id ?term-id-or-ids)
            (:subgoal (wait-for-ekb-xml ?result-id))))

(kbop:method
 :matches ((wait-for-ekb-xml ?result-id))
 :pre ((ekb-xml ?result-id ?ekb-xml))
 :result success)

