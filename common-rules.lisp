;;; ------------------------------------------------------------
;;; Rules for use in both blocksworld and biocuration.
;;;

;;; ------------------------------------------------------------
;;; Look up parent goal -- in collab-context
;;;
(:in-context collab-context)

;;; This is how normal subgoals and modifications look.
(<< (find-collab-parent-goal ?goal ?parent-goal)
    (as ?goal ?aid)
    (of ?aid ?parent-goal))

;;; This is how ASK-WH subgoals look.
;;; "I want to find a treatment for pancreatic cancer."
;;; "What drug could I use?"
;;;
(<< (find-collab-parent-goal ?goal ?parent-goal)
    (as ?goal ?aid)
    ;; Don't need to verify the type, but this is what it probably is.
    ;; (type ?aid query-in-context)
    (goal ?aid ?parent-goal))

;;; ------------------------------------------------------------
;;; Look up the type for a goal

(<< (get-goal-type ?goal ?type)
    (what ?goal ?what)
    (instance-of ?what ?type))

;;; ------------------------------------------------------------
;;; ASK-WH goal lookups

(<< (is-ask-what ?type ?goal ?what)
    (kqml-predicate ?goal ask-wh)
    (what ?goal ?what)
    (instance-of ?what ?type))

;;; ------------------------------------------------------------
;;; ASK-IF goal lookups

(<< (is-ask-if ?type ?goal ?what)
    (kqml-predicate ?goal ask-if)
    (query ?goal ?what)
    (instance-of ?what ?type))

