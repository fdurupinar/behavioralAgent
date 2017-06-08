;;;; Support for identifying the actor (aka the "builder"). The actor
;;;; will be moving the blocks.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
;;; Methods to choose actor.

;; Here we pose a question to the user asking who should be the
;; actor. See line 90 of TEST-WHO-MOVE.full.
;;
(kbop:method
 :matches ((determine-actor ?goal ?reply-id))
 :on-ready ((:gentemp ?question-id "question-")
            (:ask-question ?goal ?reply-id ?question-id)
            (:note "ask who should act"))
 :result success)

;; Here we handle the user's answer to the question of who is the
;; actor. If the actor is valid, we mark this goal done. If the actor
;; isn't valid, we report a failure for the goal.
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((what ?goal ?wid)
       (instance-of ?wid handle-answer)
       (answer ?wid ?aid)
       (kqml-predicate ?aid answer)
       (value ?aid ?vid)
       (refers-to ?vid ?who)
       (is-valid-actor ?who))
 :on-ready (;; (:store (actor ont::user) collab-context)
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((what ?goal ?wid)
       (instance-of ?wid handle-answer)
       (answer ?wid ?aid)
       (kqml-predicate ?aid answer)
       (value ?aid ?vid)
       (:uninferrable
        (refers-to ?vid ?who)
        (is-valid-actor ?who)))
 :on-ready (;; (:store (actor ont::user) collab-context)
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (FAILURE :WHAT ?goal
                                             :REASON INVALID-ACTOR))))
 :result success)

;;; ------------------------------------------------------------
;;; Changing the actor
;;;
;;; Motivating dialog:
;;; user: make a column
;;; system: how about I put ...
;;; user: I will do it
;;;
;;; This leads to a modification with a what of type
;;; ONT::EXECUTE. Here we recognize a what-next for ONT::EXECUTE when
;;; it reflects a change in user.
;;;
;;; If the user says "I will move it", the evaluate is for a subgoal
;;; with what of type ONT::CAUSE-MOVE.
;;;
;;; Since that goal might be changing a bit, maybe we want to cue off
;;; the goal being a modification. That is... if the goal is a
;;; modification, we should modify things.
;;;
;;; FIXME Perhaps this doesn't even need to be a WHAT-NEXT. Can we
;;; just have a normlization rule that recognizes the modification and
;;; puts the actor on the modified goal?
;;;
;;; For now, we'll just do it here in the WHAT-NEXT. It makes the
;;; modification a more discrete event.
;;;
(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((what ?goal ?wid)
       (modification ?modified-goal ?goal)
       (actor-for ?goal ?actor))
 :on-ready ((:unstore (actor-for ?modified-goal ?any-actor))
            (:store (actor-for ?modified-goal ?actor))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
 :result success)

;;; [jrye:20170420.0742CST] Apparently we do not get a modification
;;; anymore, now we get a subgoal. Motivating dialog:
;;; [4/20/2017 7:24:29 AM] system: How about you put B1 on the table?
;;; [4/20/2017 7:24:33 AM] user: you do it
;;;
;;; To respond to this, we need an EVALUATE handler that recognizes
;;; this. And then a WHAT-NEXT that effects the change.
(kbop:method
 :matches ((evaluate ?goal))
 :pre ((get-goal-type ?goal ONT::OBJECTIVE-INFLUENCE)
       (find-collab-parent-goal ?goal ?modified-goal)
       (actor-for ?goal ?actor))
 :on-ready ((:note "ACCEPTABLE")
            (:store (evaluate-result ?goal acceptable)))
 :result success)

(kbop:method
 :matches ((what-next ?goal ?reply-id))
 :pre ((get-goal-type ?goal ONT::OBJECTIVE-INFLUENCE)
       (find-collab-parent-goal ?goal ?modified-goal)
       (actor-for ?goal ?actor))
 :on-ready ((:unstore (actor-for ?modified-goal ?any-actor))
            (:store (actor-for ?modified-goal ?actor))
            (:report-status ?goal ?reply-id
                            (REPORT :content
                                    (EXECUTION-STATUS :GOAL ?goal :STATUS ont::done))))
 :result success)



;;; ------------------------------------------------------------
;;; Rules to look up actor.
;;;
(:in-context collab-context)

;;; This is the main query used elsewhere. The purpose is to return a
;;; valid actor for a goal, if there is one.
(<< (get-valid-actor ?goal ?actor ?source)
    (get-any-actor ?goal ?actor ?source)
    (is-valid-actor ?actor))

(<< (is-valid-actor ?actor)
    (:set-member ?actor (set-fn ont::user ont::sys)))

;;; FIXME Should these become normalization rules.

;; Best choice, get actor for goal.
(<< (get-any-actor ?goal ?actor ?source)
    (get-actor-for-goal ?goal ?actor ?source))

;; If no actor for goal, check for a global fact.
(<< (get-any-actor ?goal ?actor ?source)
    (:uninferrable (get-actor-for-goal ?goal ?any-actor ?any-source))
    (actor ?actor)
    (:assign ?source actor-fact))

;; Match the actor on this goal.
(<< (get-actor-for-goal ?goal ?actor ?source)
    (actor-for ?goal ?actor)
    (:assign ?source ?goal))

;; If no actor for this goal, check the parent.
(<< (get-actor-for-goal ?goal ?actor ?source)
    (:uninferrable (actor-for ?goal ?any-actor))
    (find-collab-parent-goal ?goal ?parent-goal)
    (get-actor-for-goal ?parent-goal ?actor ?source))

;; If we want these sort of complicated mappings, do them as
;; normalization rules.

;; ;; Normal answer to query of who should do it.
;; (<< (get-actor-for-this-goal ?g ?actor ?source)
;;     (what ?g ?wid)
;;     (agent ?wid ?aid)
;;     (refers-to ?aid ?actor)
;;     (:assign ?source ?g))

;; ;; Modification of goal.
;; (<< (get-actor-for-this-goal ?g ?actor ?source)
;;     (modification ?g ?mid)
;;     (agent ?mid ?aid)
;;     (refers-to ?aid ?actor)
;;     (:assign ?source ?g))

;; ;; Or if we had an answer to our question.
;; (<< (get-actor-for-this-goal ?g ?actor ?source)
;;     (pertains-to ?question ?g)
;;     (to ?answer ?question)
;;     (what ?answer ?wid)
;;     (instance-of ?wid who)
;;     (value ?answer ?vid)
;;     (refers-to ?vid ?actor)
;;     (:assign ?source ?g))

;;; ------------------------------------------------------------
;;; Recognize when a goal is a modification of another goal.
(:in-context collab-context)

(<< (modification ?modified-goal ?goal)
    (as ?goal ?aid)
    (kqml-predicate ?aid modification)
    (of ?aid ?modified-goal))


