;;;; Support for applying constraints to our imagined structures.
;;;;
(:in-context exec-methods)

;;; ------------------------------------------------------------
(kbop:method
 :matches ((make-left-right ?envisionment))
 :on-ready (;; Prepare a context with the change we are making.
            (:gentemp ?criteria-ctx "criteria")
            (:store (kbop:rule
                     :lhs ((or (elements-sequence ?row ?seq)
                               (elements-reversible-sequence ?row ?seq))
                           (:elt-at ?seq ?index ?a)
                           (:+ ?next ?index 1)
                           (:elt-at ?seq ?next ?b)
                           ;; (isa ?a block)
                           ;; (isa ?b block)
                           )
                     :rhs ((x-greater ?b ?a)))
                    ?criteria-ctx)
            ;; Apply it to the envisionment.
            (:subgoal (forward-chain-constraints ?envisionment ?criteria-ctx)))
 :result success)

;;; ------------------------------------------------------------
;;; Determine and, if necessary, apply constraints to an envisionment.

(kbop:method
 :matches ((find-and-apply-constraints ?goal ?envisionment))
 :pre ((:uninferrable (constraints ?goal ?constraints-id)))
 :on-ready ((:note "no constraints"))
 :result success)

(kbop:method
 :matches ((find-and-apply-constraints ?goal ?envisionment))
 :pre ((constraints ?goal ?constraints-id))
 :on-ready ((:subgoal (apply-constraints ?constraints-id ?envisionment)))
 :result success)

(kbop:method
 :matches ((apply-constraints ?constraints-id ?envisionment))
 :on-ready (;; Prepare a context with the changes we are making.
            (:gentemp ?criteria-ctx "criteria")
            ;; Collect the criteria.
            (:subgoal (prepare-criteria ?constraints-id ?criteria-ctx))
            ;; Apply them to the envisionment.
            (:subgoal (forward-chain-constraints ?envisionment ?criteria-ctx)))
 :result success)

;;; ------------------------------------------------------------
;;; Prepare criteria
;;;
;;; This populates a context with criteria based on the
;;; constraints. Initially, this is used only by the renvisionment;
;;; but eventually we would like to do it for the initial envisionment
;;; as well.

;;; Actually determine real criteria.
;;;
;;; FIXME This probably needs to become more general. Here we just
;;; make it work for colors.
;;;
;; FIXME Note that our constraints include an (isa ?cid ?type). We
;; could/should use that as part of the criteria preparation.

(kbop:method
 :matches ((prepare-criteria ?constraints-id ?criteria-context))
 :pre ((:uninferrable (constraint ?constraints-id ?cid)))
 :on-ready ((:store (constraint-result ?constraints-id NO-CONSTRAINTS-FOUND)))
 :result success)

(kbop:method
 :matches ((prepare-criteria ?constraints-id ?criteria-context))
 :pre ((constraint ?constraints-id ?cid)
       (:uninferrable
        (get-color-constraint ?constraints-id ?scene-color)))
 :on-ready ((:note "no color")
            (:store (constraint-result ?constraints-id CONSTRAINT-MISSING-COLOR)))
 :result success)

(kbop:method
 :matches ((prepare-criteria ?constraints-id ?criteria-context))
 :pre ((constraint ?constraints-id ?color-id)
       (get-color-constraint ?constraints-id ?scene-color))
 :on-ready ((:subgoal (add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context)))
 :result success)

;; Bottom/top
(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :pre ((get-location-constraint ?constraints-id ?location ?quantity)
       (:set-member ?location (set-fn bottom-of first-of left-of)))
 :on-ready ((:note ?location ?scene-color)
            (:store (kbop:rule
                     :lhs ((or (elements-sequence ?stack ?seq)
                               (elements-reversible-sequence ?stack ?seq))
                           (:elt-at ?seq ?index ?block)
                           (:< ?index ?quantity)
                           (isa ?block block))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context)
            (:store (constraint-result ?constraints-id OK)))
 :result success)

(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :pre ((get-location-constraint ?constraints-id ?location ?quantity)
       (:set-member ?location (set-fn top-of last-of right-of)))
 :on-ready ((:note ?location ?scene-color)
            (:store (kbop:rule
                     :lhs ((or (elements-sequence ?stack ?seq)
                               (elements-reversible-sequence ?stack ?seq))
                           (:elt-at ?seq ?index ?block)
                           (:cardinality ?seq ?seq-size)
                           (:- ?min ?seq-size ?quantity)
                           (:>= ?index ?min)
                           (isa ?block block))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context)
            (:store (constraint-result ?constraints-id OK)))
 :result success)

;; Ends
(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :pre ((get-location-constraint ?constraints-id ?location ?quantity)
       (:set-member ?location (set-fn ends-of)))
 :on-ready ((:note ?location ?scene-color)
            ;; Store a rule for stacks.
            (:store (kbop:rule
                     :lhs ((or (elements-sequence ?stack ?seq)
                               (elements-reversible-sequence ?stack ?seq))
                           (:cardinality ?seq ?seq-size)
                           (:- ?end ?seq-size 1)
                           (or (:elt-at ?seq 0 ?block)
                               (:elt-at ?seq ?end ?block))
                           (isa ?block block))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context))
 :result success)

;; <n>th
(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :pre ((get-location-constraint ?constraints-id ?location ?quantity)
       (:numberp ?location))
 :on-ready ((:note ?location ?scene-color)
            ;; Store a rule for stacks.
            (:store (kbop:rule
                     :lhs ((or (elements-sequence ?stack ?seq)
                               (elements-reversible-sequence ?stack ?seq))
                           (:- ?index ?location 1)
                           (:elt-at ?seq ?index ?block)
                           (isa ?block block))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context))
 :result success)

;; Middle
;; FIXME This is way more complicated than we would like. We should
;; not be having crazy differences between the top-/bottom-of and
;; this.
;;
(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :pre ((get-location-constraint ?constraints-id ?location ?quantity)
       (:set-member ?location (set-fn middle-of)))
 :on-ready ((:note ?location ?scene-color)
            ;; Store a rule for stacks.
            (:store (kbop:rule
                     :lhs ((isa ?stack stack)
                           (elements ?stack ?block)
                           (isa ?block block)
                           (:uninferrable (top-of ?stack ?block))
                           (:uninferrable (bottom-of ?stack ?block)))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context)
            ;; Store a rule for rows.
            (:store (kbop:rule
                     :lhs ((isa ?row row)
                           (elements ?row ?block)
                           (isa ?block block)
                           (:uninferrable (end-of ?row ?block))
                           (:uninferrable (end-of ?row ?block)))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context))
 :result success)

;; The "rest" of the blocks
(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :pre ((get-location-constraint ?constraints-id ?location ?quantity)
       (:set-member ?location (set-fn rest-of)))
 :on-ready ((:note ?location ?scene-color)
            (:store (kbop:rule
                     :lhs ((elements ?structure ?block)
                           (:uninferrable (color-of ?block ?any-color))
                           (isa ?block block))
                     ;; :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context)
            (:store (constraint-result ?constraints-id OK)))
 :result success)

;; These are the fallbacks for applying color constraints. Will only
;; be tried if the normal methods fail.
(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :priority -1
 :pre ((get-location-constraint ?constraints-id ?location ?quantity))
 :on-ready ((:note "invalid location" ?location)
            (:store (constraint-result ?constraints-id CONSTRAINT-INVALID-LOCATION)))
 :result success)

(kbop:method
 :matches ((add-color-constraint-rule ?constraints-id ?scene-color ?criteria-context))
 :priority -99
 :on-ready ((:note "ALL" ?scene-color)
            (:store (kbop:rule
                     :lhs ((isa ?block block))
                     :rhs-unstore ((color-of ?block ?c))
                     :rhs ((color-of ?block ?scene-color)))
                    ?criteria-context)
            (:store (constraint-result ?constraints-id OK)))
 :result success)

;;; ------------------------------------------------------------
;;; Actually applies criteria to an envisionment.

(kbop:method
 :matches ((forward-chain-constraints ?new-envisionment ?criteria-ctx))
 :on-ready ((:forward-chain ?new-envisionment ?new-envisionment ?criteria-ctx)
            ;; Record the criteria for posterity.
            (:store (criteria ?new-envisionment ?criteria-ctx)))
 :result success)


;;; ------------------------------------------------------------
;;; Rules for collecting criteria
;;;
(:in-context collab-context)

;;; Get location and quantity. If the quantity is constrained by what
;;; the user said, use it.
(<< (get-location-constraint ?constraints-id ?location ?quantity)
    (get-quantity-constraint ?constraints-id ?quantity)
    (constraint ?constraints-id ?location-id)
    (location ?location-id ?location))

;; If there was no quantity constraint, default to 1.
(<< (get-location-constraint ?constraints-id ?location ?quantity)
    (:uninferrable (get-quantity-constraint ?constraints-id ?q))
    (:assign ?quantity 1)
    (constraint ?constraints-id ?location-id)
    (location ?location-id ?location))

(<< (get-quantity-constraint ?constraints-id ?quantity)
    (constraint ?constraints-id ?quantity-id)
    (quantity ?quantity-id ?quantity))

(<< (get-color-constraint ?constraints-id ?scene-color)
    (constraint ?constraints-id ?color-id)
    (color ?color-id ?scene-color))

