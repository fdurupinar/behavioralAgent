;;;; Support for CAUSE-EFFECT (i.e., modification) goals.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; Methods to handle CAUSE-EFFECT goals.

;;; For now, all CAUSE-EFFECT goals are acceptable. The real work
;;; happens in the WHAT-NEXT.
(kbop:method
 :matches ((evaluate ?goal))
 :pre ((is-cause-effect-goal ?what))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal ACCEPTABLE)))
 :result success)

;;; We see cause-effect when TRIPS treated the user's utterance as a
;;; subgoal. We see have-property when TRIPS thought it was a goal
;;; modification.
;;;
;;; This is the difference between:
;;; "make the blocks red" and "the blocks should be red"
;;;
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((is-cause-effect-goal ?goal))
 :on-ready ((:subgoal (revise-and-report ?goal ?reply-id)))
 :result success)

(kbop:method
 :matches ((revise-and-report ?goal ?reply-id))
 :pre ((:uninferrable (constraints ?goal ?cid)))
 :on-ready ((:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON NO-CONSTRAINTS-FOUND))))
 :result success)

(kbop:method
 :matches ((revise-and-report ?goal ?reply-id))
 :pre ((constraints ?goal ?constraints-id))
 :on-ready ((:subgoal (revise-envisionment ?goal ?constraints-id ?reply-id)))
 :result success)


;;; ------------------------------------------------------------
;;; Support for re-envisioning.

;; If this happens, we recognized that we have constraints, but we
;; don't have anything to modify.
(kbop:method
 :matches ((revise-envisionment ?goal ?constraints-id ?reply-id))
 :pre ((:uninferrable (find-create-goal ?goal ?create-goal)))
 :on-ready ((:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON NO-CREATE-GOAL))))
 :result success)

;; Okay. This is pretty good. We have constraints and a create goal to
;; update. This is where we should actually do some work.
(kbop:method
 :matches ((revise-envisionment ?goal ?constraints-id ?reply-id))
 :pre ((find-create-goal ?goal ?create-goal))
 :on-ready (;; This is where the new envisionment will go.
            (:gentemp ?new-envisionment "renvision")
            (:subgoal (renvision ?create-goal ?new-envisionment))
            ;; Actually revise the envisionment.
            (:subgoal (apply-constraints ?constraints-id ?new-envisionment))
            ;; Verify and plan.
            (:subgoal (verify ?new-envisionment))
            (:subgoal (plan ?create-goal ?new-envisionment))
            ;; Report a result.
            (:subgoal (report-renvision-result ?create-goal ?new-envisionment ?constraints-id ?goal ?reply-id))
            ))

;; We check for errors with both the re-envisionment and the normal
;; plan eval errors.
(kbop:method
 :matches ((report-renvision-result ?create-goal ?new-envisionment ?constraints-id ?goal ?reply-id))
 :pre ((determine-renvision-failure ?new-envisionment ?result))
 :on-ready((:report-status ?goal ?reply-id
                           (REPORT :content
                                   (FAILURE :WHAT ?goal
                                            :REASON ?result))))
 :result success)

(kbop:method
 :matches ((report-renvision-result ?create-goal ?new-envisionment ?constraints-id ?goal ?reply-id))
 :pre ((:uninferrable (determine-renvision-failure ?new-envisionment ?r))
       (determine-constraints-failure ?constraints-id ?result))
 :on-ready((:report-status ?goal ?reply-id
                           (REPORT :content
                                   (FAILURE :WHAT ?goal
                                            :REASON ?result))))
 :result success)

(kbop:method
 :matches ((report-renvision-result ?create-goal ?new-envisionment ?constraints-id ?goal ?reply-id))
 :pre ((:uninferrable (determine-renvision-failure ?new-envisionment ?r1))
       (:uninferrable (determine-constraints-failure ?constraints-id ?r2))
       (determine-plan-eval-failure ?new-envisionment ?result))
 :on-ready((:report-status ?goal ?reply-id
                           (REPORT :content
                                   (FAILURE :WHAT ?goal
                                            :REASON ?result))))
 :result success)

 (kbop:method
 :matches ((report-renvision-result ?create-goal ?new-envisionment ?constraints-id ?goal ?reply-id))
 :pre ((:uninferrable
        (determine-renvision-failure ?new-envisionment ?r1)
        (determine-constraints-failure ?constraints-id ?r2)
        (determine-plan-eval-failure ?new-envisionment ?r3)))
 :on-ready(;; All was okay, update envisionment for the goal.
           (:unstore (envisionment ?create-goal ?envisionment))
           (:store (envisionment ?create-goal ?new-envisionment))
           (:make-log-entry renvisionment ?new-envisionment)
           ;; Report success.
           (:report-status ?goal ?reply-id
                           (REPORT :content
                                   (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
 :result success)

;;; ------------------------------------------------------------
;;; Rules for identifying cause-effect goals.
;;;
(:in-context collab-context)

(<< (is-cause-effect-goal ?goal)
    (what ?goal ?what)
    (instance-of ?what ?type)
    (:set-member ?type (set-fn ont::cause-effect ont::have-property ont::use)))

;;; ------------------------------------------------------------
;;; Rules for looking up modification information.
;;;
(:in-context collab-context)

;; If this is a create-goal, awesome, done.
(<< (find-create-goal ?goal ?create-goal)
    (is-create-goal ?goal)
    (:assign ?create-goal ?goal))

;; Otherwise, recurse to the parent goal.
(<< (find-create-goal ?goal ?create-goal)
    (:uninferrable
     (is-create-goal ?goal))
    (find-collab-parent-goal ?goal ?parent-goal)
    (find-create-goal ?parent-goal ?create-goal))


;;; ------------------------------------------------------------
;;; Rules for renvisionment result finding.

;;; No result at all is a failure.
(<< (determine-renvision-failure ?envisionment ?result)
    (:uninferrable
     (renvision-result ?envisionment ?r))
    (:assign ?result UNABLE-TO-RENVISION))

;;; Any result besides OK is a failure.
(<< (determine-renvision-failure ?envisionment ?result)
    (renvision-result ?envisionment ?result)
    (:uninferrable (:equalp ?result OK)))

;;; Any result besides OK is a failure. No result? No problem.
(<< (determine-constraints-failure ?constraints-id ?result)
    (constraint-result ?constraints-id ?result)
    (:uninferrable (:equalp ?result OK)))
